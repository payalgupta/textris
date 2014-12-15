describe Textris::Delivery::Mail do
  let(:message) do
    Textris::Message.new(
      :from    => 'Mr Jones <+48 555 666 777>',
      :to      => ['+48 600 700 800', '+48 100 200 300'],
      :content => 'Some text',
      :texter  => 'Namespace::MyCuteTexter',
      :action  => 'my_action')
  end

  before do
    Object.send(:remove_const, :Rails) if defined?(Rails)

    module MyAppName
      class Application < OpenStruct; end
    end

    Rails = OpenStruct.new(
      :application => MyAppName::Application.new(
        :config => OpenStruct.new
      ),
      :env => 'test'
    )

    class FakeMail
      def self.deliveries
        @deliveries || []
      end

      def self.deliver(message)
        @deliveries ||= []
        @deliveries.push(message)
      end

      def initialize(message)
        @message = message
      end

      def deliver
        self.class.deliver(@message)
      end
    end

    allow(Textris::Delivery::Mail::Mailer
        ).to receive(:notify) do |from, to, subject, body|
      FakeMail.new(
        :from    => from,
        :to      => to,
        :subject => subject,
        :body    => body)
    end
  end

  it 'responds to :send_message_to_all' do
    expect(Textris::Delivery::Mail).to respond_to(:send_message_to_all)
  end

  it 'invokes ActionMailer for each recipient' do
    expect(Textris::Delivery::Mail::Mailer).to receive(:notify)

    Textris::Delivery::Mail.send_message_to_all(message)

    expect(FakeMail.deliveries.count).to eq 2
  end

  it 'reads templates from configuration' do
    Rails.application.config = OpenStruct.new(
      :textris_mail_from_template    => 'a',
      :textris_mail_to_template      => 'b',
      :textris_mail_subject_template => 'c',
      :textris_mail_body_template    => 'd')

    Textris::Delivery::Mail.send_message_to_all(message)

    expect(FakeMail.deliveries.last).to eq(
      :from    => 'a',
      :to      => 'b',
      :subject => 'c',
      :body    => 'd')
  end

  it 'defines default templates' do
    Rails.application.config = OpenStruct.new

    Textris::Delivery::Mail.send_message_to_all(message)

    expect(FakeMail.deliveries.last[:from]).to    be_present
    expect(FakeMail.deliveries.last[:to]).to      be_present
    expect(FakeMail.deliveries.last[:subject]).to be_present
    expect(FakeMail.deliveries.last[:body]).to    be_present
  end

  it 'applies all template interpolations properly' do
    interpolations = %w{app env texter action from_name
      from_phone to_phone content}

    Rails.application.config = OpenStruct.new(
      :textris_mail_to_template => interpolations.map { |i| "%{#{i}}" }.join('-'))

    Textris::Delivery::Mail.send_message_to_all(message)

    expect(FakeMail.deliveries.last[:to].split('-')).to eq([
      'MyAppName', 'test', 'MyCute', 'my_action', 'Mr Jones', '48555666777', '48100200300', 'Some text'])
  end

  it 'applies all template interpolation modifiers properly' do
    interpolations = %w{app:d texter:dhx action:h from_phone:p}

    Rails.application.config = OpenStruct.new(
      :textris_mail_to_template => interpolations.map { |i| "%{#{i}}" }.join('--'))

    Textris::Delivery::Mail.send_message_to_all(message)

    expect(FakeMail.deliveries.last[:to].split('--')).to eq([
      'my-app-name', 'My cute', 'My action', '+48 55 566 67 77'])
  end

  it 'applies all template interpolations properly when values missing' do
    message = Textris::Message.new(
      :to      => ['+48 600 700 800', '+48 100 200 300'],
      :content => 'Some text')

    interpolations = %w{app env texter action from_name
      from_phone to_phone content}

    Rails.env = nil
    Rails.application = OpenStruct.new
    Rails.application.config = OpenStruct.new(
      :textris_mail_to_template => interpolations.map { |i| "%{#{i}}" }.join('-'))

    Textris::Delivery::Mail.send_message_to_all(message)

    expect(FakeMail.deliveries.last[:to].split('-')).to eq([
      'unknown', 'unknown', 'unknown', 'unknown', 'unknown', 'unknown', '48100200300', 'Some text'])
  end
end