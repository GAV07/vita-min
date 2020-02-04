module Questions
  class MarriedAllYearController < QuestionsController
    layout "yes_no_question"

    def section_title
      "Personal Information"
    end

    def self.show?(intake)
      intake.married_yes? || intake.married_unfilled?
    end

    def no_illustration?
      true
    end
  end
end