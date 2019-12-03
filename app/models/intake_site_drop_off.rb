class IntakeSiteDropOff < ApplicationRecord
  SIGNATURE_METHODS = %w(in_person e_signature)
  INTAKE_SITES = [
      "Clayton Early Learning Center",
      "Denver Housing Authority - Connections",
      "Denver Housing Authority - Mulroy",
      "Denver Housing Authority - Quigg Newton",
      "Denver Housing Authority - Westwood",
      "Adams City High School",
      "Denver Human Services - East Office",
      "Denver Human Services - Montbello",
      "Dress for Success",
      "Denver International Airport",
      "Fort Collins Tax Site",
      "Lamar Community College",
      "Northeastern Junior College",
      "Pueblo Community College",
      "Trinidad State Junior College - Alamosa",
      "Trinidad State Junior College - Trinidad",
  ]
  CERTIFICATION_LEVELS = %w(Basic Advanced HSA)

  strip_attributes only: [:name, :email, :phone_number, :additional_info]

  validates_presence_of :name
  validates :intake_site, inclusion: { in: INTAKE_SITES, message: "Please select an intake site." }
  validates :signature_method, inclusion: { in: SIGNATURE_METHODS, message: "Please select a pickup method." }
  validates :certification_level, allow_blank: true, inclusion: {
      in: CERTIFICATION_LEVELS,
      message: "Please select a certification level."
  }
  validates :email, allow_blank: true, format: {
      with: URI::MailTo::EMAIL_REGEXP,
      message: "Please enter a valid email.",
  }
  validates :phone_number, allow_blank: true, phone: { message: "Please enter a valid phone number." }
  validate :has_document_bundle?
  validate :has_valid_pickup_date?

  has_one_attached :document_bundle

  def has_document_bundle?
    doc_is_attached = document_bundle.attached?
    errors.add(:document_bundle, "Please choose a file.") unless doc_is_attached
    doc_is_attached
  end

  def phone_number=(value)
    if value.present? && value.is_a?(String)
      unless value[0] == "1" || value[0..1] == "+1"
        value = "1#{value}" # add USA country code
      end
      self[:phone_number] = Phonelib.parse(value).sanitized
    else
      self[:phone_number] = value
    end
  end

  def formatted_phone_number
    Phonelib.parse(phone_number).local_number
  end

  def pickup_date_string=(value)
    if value.present? && value.is_a?(String)
      value = value.strip
      begin
        self.pickup_date = Date.strptime(value, "%m/%d/%Y")
      rescue ArgumentError => error
        raise error unless error.to_s == "invalid date"
        @pickup_date_string = value
      end
    end
  end

  def pickup_date_string
    return I18n.l(pickup_date) if pickup_date.present?
    @pickup_date_string
  end

  def has_valid_pickup_date?
    if pickup_date_string.present?
      begin
        Date.strptime(pickup_date_string, "%m/%d/%Y")
        return true
      rescue ArgumentError => error
        errors.add(:pickup_date_string, "Please enter a valid date.")
        errors.add(:pickup_date, "Please enter a valid date.")
        return false
      end
    end
  end

  def formatted_signature_method
    Date::DATE_FORMATS
    {
      "e_signature" => "E-Signature",
      "in_person" => "In Person"
    }[signature_method]
  end

  def error_summary
    if errors.present?
      visible_errors = errors.messages.select{ |key, _| key != :pickup_date }
      concatenated_message_strings = visible_errors.map{ |key, messages| messages.join(" ")}.join(" ")
      "Errors: " + concatenated_message_strings
    end
  end

  def self.intake_sites
    INTAKE_SITES
  end

  def self.certification_levels
    CERTIFICATION_LEVELS
  end

  def self.find_prior_drop_off(new_drop_off)
    if new_drop_off.email.present?
      email_match = where(email: new_drop_off.email).first
      return email_match if email_match
    end

    if new_drop_off.phone_number.present?
      phone_match = where(phone_number: new_drop_off.phone_number, name: new_drop_off.name).first
      return phone_match if phone_match
    end

    if new_drop_off.phone_number.blank? && new_drop_off.email.blank?
      name_only_match = where(name: new_drop_off.name).first
      return name_only_match if name_only_match
    end
  end
end