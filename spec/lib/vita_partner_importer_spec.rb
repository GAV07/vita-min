require 'rails_helper'

class TestImporter
  class << self
    include VitaPartnerImporter
  end
end

RSpec.describe VitaPartnerImporter do
  describe "#upsert_vita_partners" do
    let(:zendesk_group_id) { "360000000000" }
    let(:fake_partners_yaml) do
      {
        "vita_partners" => [{
          "name" => "Tax Help Colorado",
          "zendesk_instance_domain" => "eitc",
          "zendesk_group_id" => zendesk_group_id,
          "display_name" => "Tax Help Colorado",
          "source_parameters" => ["test-source"],
          "states" => ["CO"],
          "logo_path" => "",
        }],
      }
    end

    before do
      allow(YAML).to receive(:load_file).and_call_original
      allow(YAML).to receive(:load_file)
        .with(VitaPartnerImporter::VITA_PARTNERS_YAML)
        .and_return(fake_partners_yaml)
    end

    it "inserts a new partner" do
      expect do
        TestImporter.upsert_vita_partners
      end.to change(VitaPartner, :count).by(1)

      created = VitaPartner.last
      expect(created.name).to eq("Tax Help Colorado")
      expect(created.zendesk_group_id).to eq(zendesk_group_id)
      expect(created.source_parameters.length).to eq(1)
      expect(created.source_parameters.first.code).to eq("test-source")
      expect(created.states.length).to eq(1)
      expect(created.states.first.abbreviation).to eq("CO")
    end

    context "when a partner exists with that group ID" do
      let!(:existing_partner) do
        create(:vita_partner, name: "Old Name", zendesk_group_id: zendesk_group_id)
      end

      it "updates the existing partner" do
        expect do
          TestImporter.upsert_vita_partners
        end.to change { existing_partner.reload.name }
          .from("Old Name").to("Tax Help Colorado")
      end
    end
  end
end