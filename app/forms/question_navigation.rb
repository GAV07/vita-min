class QuestionNavigation
  FLOW = [
    # Personal Information
    Questions::IdentityController,
    Questions::ConsentController,
    Questions::WelcomeController,
    Questions::MailingAddressController,
    Questions::NotificationPreferenceController,

    # Marital Status
    Questions::EverMarriedController,
    Questions::MarriedController,
    Questions::LivedWithSpouseController,
    Questions::SeparatedController,
    Questions::SeparatedYearController,
    Questions::DivorcedController,
    Questions::DivorcedYearController,
    Questions::WidowedController,
    Questions::WidowedYearController,
    Questions::FilingJointController,

    # Spouse authentication
    Questions::SpouseIdentityController,
    Questions::WelcomeSpouseController,

    # Dependents
    Questions::HadDependentsController,

    # Income
    Questions::JobCountController,
    Questions::WagesController,
    Questions::TipsController,
    Questions::SelfEmploymentController,
    Questions::SelfEmploymentLossController,
    Questions::RetirementIncomeController,
    Questions::SocialSecurityIncomeController,
    Questions::UnemploymentIncomeController,
    Questions::DisabilityIncomeController,
    Questions::InterestIncomeController,
    Questions::AssetSaleIncomeController,
    Questions::AssetSaleLossController,
    Questions::ReceivedAlimonyController,
    Questions::RentalIncomeController,
    Questions::FarmIncomeController,
    Questions::GamblingIncomeController,
    Questions::LocalTaxRefundController,
    Questions::OtherIncomeController,
    Questions::OtherIncomeTypesController,

    # Expenses
    Questions::MortgageInterestController,
    Questions::LocalTaxController,
    Questions::MedicalExpensesController,
    Questions::CharitableContributionsController,
    Questions::StudentLoanInterestController,
    Questions::DependentCareController,
    Questions::RetirementContributionsController,
    Questions::SchoolSuppliesController,
    Questions::PaidAlimonyController,
    Questions::StudentController,
    Questions::SoldHomeController,
    Questions::HsaController,
    Questions::HealthInsuranceController,

    # Life Events
    Questions::HomebuyerCreditController,
    Questions::DebtForgivenController,
    Questions::DisasterLossController,
    Questions::AdoptedChildController,
    Questions::TaxCreditDisallowedController,
    Questions::IrsLetterController,
    Questions::EstimatedTaxPaymentsController,

    # Additional Questions
    Questions::AdditionalInfoController,

    # Documents
    Questions::W2sController,
    Questions::Form1095asController,
    Questions::Form1098sController,
    Questions::Form1098esController,
    Questions::Form1098tsController,
    Questions::Form1099asController,
    Questions::Form1099bsController,
    Questions::Form1099csController,
    Questions::Form1099divsController,
    Questions::Form1099intsController,
    Questions::Form1099ksController,
    Questions::Form1099miscsController,
    Questions::Form1099rsController,
    Questions::Form1099ssController,
    Questions::Form1099sasController,
    Questions::Form1099ssdisController,
    Questions::Form1099gsController,
    Questions::Form5498sasController,
    Questions::IraStatementsController,
    Questions::Rrb1099sController,
    Questions::SsnItinsController,
    Questions::Ssa1099sController,
    Questions::StudentAccountStatementsController,
    Questions::W2gsController,
    Questions::PriorTaxReturnsController,
    Questions::AdditionalDocumentsController,
    Questions::DocumentsOverviewController,

    Questions::InterviewSchedulingController,

    Questions::WelcomeController, # TODO: remove this
  ].freeze

  class << self
    delegate :first, to: :controllers

    def controllers
      FLOW
    end
  end

  delegate :controllers, to: :class

  def initialize(current_controller)
    @current_controller = current_controller
  end

  def next
    return unless index

    controllers_until_end = controllers[index + 1..-1]
    seek(controllers_until_end)
  end

  private

  def index
    controllers.index(@current_controller.class)
  end

  def seek(list)
    list.detect do |controller_class|
      controller_class.show?(@current_controller.current_intake)
    end
  end
end
