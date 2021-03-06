# == Schema Information
#
# Table name: ticket_statuses
#
#  id              :bigint           not null, primary key
#  intake_status   :string           not null
#  return_status   :string           not null
#  verified_change :boolean          default(TRUE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  intake_id       :bigint
#  ticket_id       :integer
#
# Indexes
#
#  index_ticket_statuses_on_intake_id  (intake_id)
#
# Foreign Keys
#
#  fk_rails_...  (intake_id => intakes.id)
#
class TicketStatus < ApplicationRecord
  belongs_to :intake

  def status_changed?(intake_status:, return_status:)
    self.intake_status != intake_status || self.return_status != return_status
  end

  def send_mixpanel_event(context = {})
    MixpanelService.send_event(
        event_id: intake.visitor_id,
        event_name: 'ticket_status_change',
        data: context.merge(MixpanelService.data_from(self)),
        subject: intake
    )
  end

  def intake_status_label
    EitcZendeskInstance::INTAKE_STATUS_LABELS[intake_status]
  end

  def return_status_label
    EitcZendeskInstance::RETURN_STATUS_LABELS[return_status]
  end

  private

end
