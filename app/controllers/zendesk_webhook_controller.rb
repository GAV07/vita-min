class ZendeskWebhookController < ApplicationController
  skip_before_action :verify_authenticity_token, :set_visitor_id, :set_source, :set_referrer, :set_utm_state
  before_action :authenticate

  def incoming
    case json_payload[:method]
    when "updated_sms"
      incoming_sms
    when "updated_ticket"
      updated_ticket
    end
    head :ok if params[:zendesk_webhook].present?
  end

  def incoming_sms
    phone_number = json_payload["requester_phone_number"].tr("+", "")
    sms_ticket_id = json_payload["ticket_id"].to_i
    message_body = json_payload["message_body"]

    ZendeskInboundSmsJob.perform_later(
      sms_ticket_id: sms_ticket_id,
      phone_number: phone_number,
      message_body: message_body
    )
  end

  def updated_ticket
    return unless has_valid_intake_id? && intakes_for_ticket.present?
    # in rare cases, there may be multiple intakes with the same ticket id
    intakes_for_ticket.each do |intake|
      current_status = intake.current_ticket_status

      new_status = if current_status.nil?
        # new tickets are created with an initial status
        # if this is the first status, we don't know if this status changed
        intake.ticket_statuses.create(
          ticket_id: json_payload[:ticket_id],
          verified_change: false,
          **incoming_ticket_statuses
        )
      elsif current_status.status_changed?(incoming_ticket_statuses)
        intake.ticket_statuses.create(ticket_id: json_payload[:ticket_id], **incoming_ticket_statuses)
      end

      if new_status&.verified_change?
        new_status.send_mixpanel_event(mixpanel_routing_data)
      end
    end
  end

  private

  def mixpanel_routing_data
    {
      path: request.path,
      full_path: request.fullpath,
      controller_name: self.class.name.sub("Controller", ""),
      controller_action: "#{self.class.name}##{action_name}",
      controller_action_name: action_name,
    }
  end

  def intakes_for_ticket
    @intakes_for_ticket ||= Intake.where(intake_ticket_id: json_payload[:ticket_id])
  end

  def has_valid_intake_id?
    json_payload[:external_id].include?("intake-")
  end

  def incoming_ticket_statuses
    {
      intake_status: json_payload[:digital_intake_status],
      return_status: json_payload[:return_status],
    }
  end

  def json_payload
    params[:zendesk_webhook]
  end

  def authenticate
    authenticate_or_request_with_http_basic do |name, password|
      expected_name = EnvironmentCredentials.dig(:zendesk_webhook_auth, :name)
      expected_password = EnvironmentCredentials.dig(:zendesk_webhook_auth, :password)
      ActiveSupport::SecurityUtils.secure_compare(name, expected_name) &&
        ActiveSupport::SecurityUtils.secure_compare(password, expected_password)
    end
  end
end
