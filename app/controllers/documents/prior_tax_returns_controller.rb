module Documents
  class PriorTaxReturnsController < DocumentUploadQuestionController
    def self.show?(intake)
      intake.had_local_tax_refund_yes? || intake.reported_asset_sale_loss_yes?
    end

    def self.document_type
      "Prior Year Tax Return"
    end
  end
end
