require "rails_helper"

RSpec.describe ZendeskServiceHelper do
  let(:fake_zendesk_client) { double(ZendeskAPI::Client) }
  let(:fake_zendesk_ticket) { double(ZendeskAPI::Ticket, id: 2) }
  let(:fake_zendesk_user) { double(ZendeskAPI::User, id: 1) }
  let(:fake_zendesk_comment) { double(uploads: []) }
  let(:fake_zendesk_comment_body) { "" }
  let(:service) do
    class SampleService
      include ZendeskServiceHelper

      def instance
        EitcZendeskInstance
      end
    end

    SampleService.new
  end
  let(:qualified_environments) { service.qualified_environments }
  let(:unqualified_environments) { %w[test production] }

  before do
    allow(ZendeskAPI::Client).to receive(:new).and_return fake_zendesk_client
    allow(ZendeskAPI::Ticket).to receive(:new).and_return fake_zendesk_ticket
    allow(ZendeskAPI::Ticket).to receive(:find).and_return fake_zendesk_ticket
    allow(fake_zendesk_comment).to receive(:body).and_return(fake_zendesk_comment_body)
    allow(fake_zendesk_comment_body).to receive(:concat)
    allow(fake_zendesk_ticket).to receive(:comment=)
    allow(fake_zendesk_ticket).to receive(:fields=)
    allow(fake_zendesk_ticket).to receive(:tags).and_return ["old_tag"]
    allow(fake_zendesk_ticket).to receive(:tags=)
    allow(fake_zendesk_ticket).to receive(:group_id=)
    allow(fake_zendesk_ticket).to receive(:comment).and_return fake_zendesk_comment
    allow(fake_zendesk_ticket).to receive(:save).and_return true
  end

  describe "#find_end_user" do
    let(:search_results) { [fake_zendesk_user] }

    before do
      allow(service).to receive(:search_zendesk_users).with(kind_of(String)).and_return(search_results)
    end

    context "when email is present" do
      it "searches by email" do
        result = service.find_end_user(nil, "test@example.com", nil)
        expect(service).to have_received(:search_zendesk_users).with("email:test@example.com")
        expect(result).to eq(fake_zendesk_user)
      end

      context "when there are no email matches" do
        before do
          allow(service).to receive(:search_zendesk_users).with("email:test@example.com").and_return([])
          allow(service).to receive(:search_zendesk_users).with("name:\"Barry Banana\" phone:14155551234").and_return(search_results)
        end

        context "without exact match" do
          it "searches by name and phone" do
            result = service.find_end_user("Barry Banana", "test@example.com", "14155551234")
            expect(service).to have_received(:search_zendesk_users).with("email:test@example.com")
            expect(service).to have_received(:search_zendesk_users).with("name:\"Barry Banana\" phone:14155551234")
            expect(result).to eq(fake_zendesk_user)
          end
        end

        context "when it wants an exact match" do
          it "doesn't return users with a different email address" do
            result = service.find_end_user("Barry Banana", "test@example.com", "14155551234", exact_match: true)
            expect(service).to have_received(:search_zendesk_users).with("email:test@example.com")
            expect(result).to be_nil
          end
        end
      end
    end

    context "when only phone and name are present" do
      it "searches with phone and name" do
        service.find_end_user("Gary Guava", nil, "14155555555")
        expect(service).to have_received(:search_zendesk_users).with("name:\"Gary Guava\" phone:14155555555")
      end
    end

    context "when only name is present" do
      it "searches with only name" do
        service.find_end_user("Gary Guava", nil, nil)
        expect(service).to have_received(:search_zendesk_users).with("name:\"Gary Guava\" ")
      end
    end

    context "when only phone is present" do
      it "searches with only phone" do
        service.find_end_user(nil, nil, "14155555555")
        expect(service).to have_received(:search_zendesk_users).with("phone:14155555555")
      end
    end

    context "when there are no search results" do
      let(:search_results) { [] }
      it "returns nil" do
        result = service.find_end_user("Gary Guava", "test@example.com", "14155555555")
        expect(result).to eq nil
      end
    end

    context "when we need an exact match" do
      let(:match_with_extra_phone) { double(ZendeskAPI::User, id: 5, name: "Percy Plum", phone: "14155554321", email: nil) }
      let(:match_with_extra_email) { double(ZendeskAPI::User, id: 6, name: "Percy Plum", phone: nil, email: "shoe@hoof.horse") }
      let(:exact_match) { double(ZendeskAPI::User, id: 9, name: "Percy Plum", email: nil, phone: nil) }

      context "and it exists" do
        let(:search_results) { [match_with_extra_phone, match_with_extra_email, exact_match] }

        it "returns the exact match" do
          result = service.find_end_user("Percy Plum", nil, nil, exact_match: true)
          expect(result).to eq exact_match
        end
      end

      context "and only partial matches exist" do
        let(:search_results) { [match_with_extra_phone, match_with_extra_email] }

        it "returns nil" do
          result = service.find_end_user("Percy Plum", nil, nil, exact_match: true)
          expect(result).to eq nil
        end
      end
    end

    context "in name-qualified environments" do
      before do
        allow(service).to receive(:search_zendesk_users).with(include("(Fake User)")).and_return([])
      end

      it "qualifies the name" do
        qualified_environments.each do |e|
          with_environment(e) do
            service.find_end_user('Percy Plum', nil, nil)
          end
        end
        expect(service).to have_received(:search_zendesk_users)
          .with(include("(Fake User)")).exactly(qualified_environments.count).times
      end
    end
  end

  describe "#find_or_create_end_user" do
    before do
      allow(service).to receive(:search_zendesk_users).with(kind_of(String)).and_return([result])
    end

    context "end user exists" do
      let(:result) { fake_zendesk_user }

      it "returns the existing user's id" do
        expect(service.find_or_create_end_user("Nancy Nectarine", nil, nil)).to eq 1
      end

      context "end user has missing phone number" do
        let(:result) { double(ZendeskAPI::User, id: 5, phone: nil, email: "test@example.com") }
        let(:phone) { "+123456789" }

        context "search includes phone number" do
          it "updates the user phone number in Zendesk" do
            expect(result).to receive(:phone=).with(phone)
            expect(result).to receive(:save!)
            expect(service.find_or_create_end_user("Nancy Nectarine", "test@example.com", phone)).to eq(result.id)
          end
        end

        context "search includes nil phone number" do
          let(:phone) { nil }

          it "does not erase the user phone number in Zendesk" do
            expect(result).not_to receive(:phone=).with(phone)
            expect(result).not_to receive(:save!)
            expect(service.find_or_create_end_user("Nancy Nectarine", "test@example.com", phone)).to eq(result.id)
          end
        end
      end
    end

    context "end user does not exist" do
      let(:result) { nil }


      context "in a normal environment" do
        before do
          allow(service).to receive(:create_end_user).and_return(fake_zendesk_user)
        end

        it "creates new user and returns their id" do
          expect(service.find_or_create_end_user("Nancy Nectarine", nil, "1234567890")).to eq 1
          expect(service).to have_received(:create_end_user).with(
              name: "Nancy Nectarine",
              email: nil,
              phone: "1234567890",
              time_zone: nil
          )
        end
      end

      context "in a name-qualified environment" do
        let(:fake_zendesk_user_list) { double("ZD Users") }
        let(:fake_zendesk_client) { double("ZD Client") }
        let(:name) { "Percy Plum" }

        before do
          allow(fake_zendesk_client).to receive(:users).and_return(fake_zendesk_user_list)
          allow(fake_zendesk_user_list).to receive(:create!).and_return(fake_zendesk_user)
          allow(service).to receive(:client).and_return(fake_zendesk_client)
        end

        it "creates a user with a qualified name" do
          qualified_environments.each do |e|
            with_environment(e) do
              service.create_end_user(name: name)
            end
          end
          expect(fake_zendesk_user_list).to have_received(:create!)
            .with(hash_including(name: "#{name} (Fake User)")).exactly(qualified_environments.count).times
        end
      end
    end
  end

  describe "#build_ticket" do
    let(:ticket_args) do
      {
        subject: "wyd",
        requester_id: 4,
        group_id: "123409218",
        body: "What's up?",
        fields: {
          "09182374" => "not_busy"
        }
      }
    end

    it "correctly calls the Zendesk API and returns a ticket object" do
      result = service.build_ticket(**ticket_args)

      expect(result).to eq fake_zendesk_ticket
      expect(ZendeskAPI::Ticket).to have_received(:new).with(
        fake_zendesk_client,
        {
          subject: "wyd",
          requester_id: 4,
          group_id: "123409218",
          external_id: nil,
          comment: {
            body: "What's up?",
          },
          fields: [
            "09182374" => "not_busy"
          ]
        }
      )
    end
  end

  describe "#create_ticket" do
    let(:success) { true }
    let(:ticket_args) do
      {
        subject: "wyd",
        requester_id: 4,
        group_id: "123409218",
        external_id: "some-object-123",
        body: "What's up?",
        fields: {
          "09182374" => "not_busy"
        }
      }
    end

    before do
      allow(service).to receive(:build_ticket).and_return(fake_zendesk_ticket)
      allow(fake_zendesk_ticket).to receive(:save!).and_return(success)
    end

    it "calls build_ticket, saves the ticket, and returns the ticket id" do
      result = service.create_ticket(**ticket_args)
      expect(result).to eq fake_zendesk_ticket
      expect(fake_zendesk_ticket).to have_received(:save!).with(no_args)
      expect(service).to have_received(:build_ticket).with(**ticket_args)
    end
  end

  describe "#assign_ticket_to_group" do
    it "finds the ticket and updates the group id" do
      result = service.assign_ticket_to_group(ticket_id: 123, group_id: "12543")

      expect(result).to eq true
      expect(fake_zendesk_ticket).to have_received(:group_id=).with("12543")
      expect(fake_zendesk_ticket).to have_received(:save).with(no_args)
    end
  end

  describe "#append_file_to_ticket" do
    let(:file) { instance_double(File) }

    before do
      allow(file).to receive(:size).and_return(1000)
    end

    it "calls the Zendesk API to get the ticket and add the comment with upload and returns true" do
      result = service.append_file_to_ticket(
        ticket_id: 1141,
        filename: "wyd.jpg",
        file: file,
        comment: "hey",
        fields: { "314324132" => "custom_field_value" }
      )
      expect(result).to eq true
      expect(fake_zendesk_ticket).to have_received(:comment=).with({ body: "hey" })
      expect(fake_zendesk_ticket).to have_received(:fields=).with({ "314324132" => "custom_field_value" })
      expect(fake_zendesk_comment.uploads).to include({file: file, filename: "wyd.jpg"})
      expect(fake_zendesk_ticket).to have_received(:save)
    end

    context "when the ticket id is missing" do
      it "raises an error" do
        expect do
          service.append_file_to_ticket(
            ticket_id: nil,
            filename: "yolo.pdf",
            file: file
          )
        end.to raise_error(ZendeskServiceHelper::MissingTicketIdError)
      end
    end

    context "when the file exceeds the maximum size" do
      let(:oversize_file) { instance_double(File) }

      before do
        allow(oversize_file).to receive(:size).and_return(100000000)
      end

      it "does not append the file" do
        result = service.append_file_to_ticket(
          ticket_id: 1141,
          filename: "big.jpg",
          file: oversize_file,
          comment: "hey",
          fields: { "314324132" => "custom_field_value" }
        )
        expect(result).to eq true
        expect(fake_zendesk_comment.uploads).not_to include({file: oversize_file, filename: "big.jpg"})
      end

      it "adds an oversize file message to the comment" do
        result = service.append_file_to_ticket(
          ticket_id: 1141,
          filename: "big.jpg",
          file: oversize_file,
          comment: "hey",
          fields: { "314324132" => "custom_field_value" }
        )
        expect(result).to eq true
        expect(fake_zendesk_comment_body).to have_received(:concat).with("\n\nThe file big.jpg could not be uploaded because it exceeds the maximum size of 20MB.")
        expect(fake_zendesk_ticket).to have_received(:save)
      end
    end
  end

  describe "#append_multiple_files_to_ticket" do
    let(:file_1) { instance_double(File) }
    let(:file_2) { instance_double(File) }
    let(:file_3) { instance_double(File) }
    let(:file_list) { [
      {file: file_1, filename: "file_1.jpg"},
      {file: file_2, filename: "file_2.jpg"},
      {file: file_3, filename: "file_3.jpg"}
    ] }

    before do
      allow(file_1).to receive(:size).and_return(1000)
      allow(file_2).to receive(:size).and_return(1000)
      allow(file_3).to receive(:size).and_return(1000)
    end

    it "calls the Zendesk API to get the ticket and add the comment with uploads and returns true" do
      result = service.append_multiple_files_to_ticket(
        ticket_id: 1141,
        file_list: file_list,
        comment: "hey",
        fields: { "314324132" => "custom_field_value" }
      )
      expect(result).to eq true
      expect(fake_zendesk_ticket).to have_received(:comment=).with({ body: "hey" })
      expect(fake_zendesk_ticket).to have_received(:fields=).with({ "314324132" => "custom_field_value" })
      expect(fake_zendesk_comment.uploads).to include({file: file_1, filename: "file_1.jpg"})
      expect(fake_zendesk_comment.uploads).to include({file: file_2, filename: "file_2.jpg"})
      expect(fake_zendesk_comment.uploads).to include({file: file_3, filename: "file_3.jpg"})
      expect(fake_zendesk_ticket).to have_received(:save)
    end

    context "when the file is not a valid size" do
      before do
        allow(file_1).to receive(:size).and_return(100000000)
        allow(file_3).to receive(:size).and_return(0)
      end

      it "does not append the file" do
        result = service.append_multiple_files_to_ticket(
          ticket_id: 1141,
          file_list: file_list,
          comment: "hey",
          fields: { "314324132" => "custom_field_value" }
        )
        expect(result).to eq true
        expect(fake_zendesk_comment.uploads).not_to include({file: file_1, filename: "file_1.jpg"})
        expect(fake_zendesk_comment.uploads).to include({file: file_2, filename: "file_2.jpg"})
        expect(fake_zendesk_comment.uploads).not_to include({file: file_3, filename: "file_3.jpg"})
        expect(fake_zendesk_ticket).to have_received(:save)
      end

      it "adds an oversize file message to the comment" do
        result = service.append_multiple_files_to_ticket(
          ticket_id: 1141,
          file_list: file_list,
          comment: "hey",
          fields: { "314324132" => "custom_field_value" }
        )
        expect(result).to eq true
        expect(fake_zendesk_comment_body).to have_received(:concat).with("\n\nThe file file_1.jpg could not be uploaded because it exceeds the maximum size of 20MB.")
        expect(fake_zendesk_comment_body).to have_received(:concat).with("\n\nThe file file_3.jpg could not be uploaded because it is empty.")
        expect(fake_zendesk_ticket).to have_received(:save)
      end
    end
  end

  describe "#append_comment_to_ticket" do
    it "calls the Zendesk API to get the ticket and add the comment" do
      result = service.append_comment_to_ticket(
        ticket_id: 1141,
        comment: "hey this is a comment",
        fields: { "314324132" => "custom_field_value" },
        tags: ["some", "tags"],
      )

      expect(result).to eq true
      expect(fake_zendesk_ticket).to have_received(:comment=).with({ body: "hey this is a comment", public: false })
      expect(fake_zendesk_ticket).to have_received(:fields=).with({ "314324132" => "custom_field_value" })
      expect(fake_zendesk_ticket).to have_received(:tags=).with(["old_tag", "some", "tags"])
      expect(fake_zendesk_ticket).to have_received(:save)
    end
  end

  describe "#get_ticket" do
    it "calls the Zendesk API to get the details for a given ticket id" do
      service.get_ticket(ticket_id: 1141)

      expect(ZendeskAPI::Ticket).to have_received(:find).with(fake_zendesk_client, id: 1141)
    end
  end

  describe "#get_ticket!" do
    before do
      allow(ZendeskAPI::Ticket).to receive(:find).and_return(nil)
    end
    it "raises a MissingTicketError if a ticket is not found" do
      expect {
        service.get_ticket!(1234)
      }.to raise_error(ZendeskServiceHelper::MissingTicketError)
    end
  end

  describe "when the service is for the UWTSA Zendesk instance" do
    let(:service) do
      class SampleService
        include ZendeskServiceHelper

        def instance
          UwtsaZendeskInstance
        end
      end

      SampleService.new
    end

    describe "#append_multiple_files_to_ticket" do
      let(:file_1) { instance_double(File) }
      let(:file_2) { instance_double(File) }
      let(:file_3) { instance_double(File) }
      let(:file_list) { [
        {file: file_1, filename: "file_1.jpg"},
        {file: file_2, filename: "file_2.jpg"},
        {file: file_3, filename: "file_3.jpg"}
      ] }

      before do
        allow(file_1).to receive(:size).and_return(8000000)
        allow(file_2).to receive(:size).and_return(1000)
        allow(file_3).to receive(:size).and_return(1000)
      end

      it "sets the maximum file size to 7MB" do
        result = service.append_multiple_files_to_ticket(
          ticket_id: 1141,
          file_list: file_list,
          comment: "hey",
          fields: { "314324132" => "custom_field_value" }
        )
        expect(result).to eq true
        expect(fake_zendesk_comment.uploads).not_to include({file: file_1, filename: "file_1.jpg"})
        expect(fake_zendesk_comment.uploads).to include({file: file_2, filename: "file_2.jpg"})
        expect(fake_zendesk_comment.uploads).to include({file: file_3, filename: "file_3.jpg"})
        expect(fake_zendesk_comment_body).to have_received(:concat).with("\n\nThe file file_1.jpg could not be uploaded because it exceeds the maximum size of 7MB.")
        expect(fake_zendesk_ticket).to have_received(:save)
      end
    end
  end

  describe "#qualify_user_name" do
    let(:name) { "Some Name" }

    it "appends a qualifier in staging, demo environment" do
      qualified_environments.each do |e|
        with_environment(e) do
          expect(service.qualify_user_name(name)).to eq("#{name} (Fake User)")
        end
      end
    end

    it "doesn't append a qualifier in test, production" do
      unqualified_environments.each do |e|
        with_environment(e) do
          expect(service.qualify_user_name(name)).to eq(name)
        end
      end
    end
  end

  describe "#zendesk_timezone" do
    it "converts iana timezone to Zendesk accepted timezones" do
      expect(service.zendesk_timezone("America/Los_Angeles")).to eq("Pacific Time (US & Canada)")
    end

    it "returns Unknown when timezone is not found" do
      expect(service.zendesk_timezone("Antarctica/Casey")).to eq("Unknown")
    end

    it "returns Unknown when timezone is nil" do
      expect(service.zendesk_timezone(nil)).to eq("Unknown")
    end
  end
end
