# == Schema Information
#
# Table name: documents
#
#  id                   :bigint           not null, primary key
#  document_type        :string           not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  documents_request_id :bigint
#  intake_id            :bigint
#  zendesk_ticket_id    :bigint
#
# Indexes
#
#  index_documents_on_documents_request_id  (documents_request_id)
#  index_documents_on_intake_id             (intake_id)
#
# Foreign Keys
#
#  fk_rails_...  (documents_request_id => documents_requests.id)
#

require "rails_helper"

describe Document do
  describe "validations" do
    let(:document) { build :document }

    it "requires essential fields" do
      document = Document.new

      expect(document).to_not be_valid
      expect(document.errors).to include :intake
      expect(document.errors).to include :document_type
    end

    describe "#document_type" do
      it "expects document_type to be a valid choice" do
        document.document_type = "Book Report"
        expect(document).not_to be_valid
        expect(document.errors).to include :document_type
      end
    end
  end

  describe ".must_have_doc_type?" do
    context "a document that we can be sure someone needs" do
      let(:doc_type) { "1095-A" }

      it { expect(subject.class.must_have_doc_type?(doc_type)).to eq true }
    end

    context "a document that we cannot be sure someone needs" do
      let(:doc_type) { "1099-DIV" }

      it { expect(subject.class.must_have_doc_type?(doc_type)).to eq false }
    end

    context "other is not a must have" do
      let(:doc_type) { "Other" }

      it { expect(subject.class.must_have_doc_type?(doc_type)).to eq false }
    end
  end

  describe ".might_have_doc_type?" do
    context "a document that we can be sure someone needs" do
      let(:doc_type) { "1095-A" }

      it { expect(subject.class.might_have_doc_type?(doc_type)).to eq false }
    end

    context "a document that we cannot be sure someone needs" do
      let(:doc_type) { "1099-DIV" }

      it { expect(subject.class.might_have_doc_type?(doc_type)).to eq true }
    end

    context "other is not a might have" do
      let(:doc_type) { "Other" }

      it { expect(subject.class.might_have_doc_type?(doc_type)).to eq false }
    end
  end
end
