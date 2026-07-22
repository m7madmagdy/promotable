require "rails_helper"

RSpec.describe Promotable do
  it "has a version number" do
    expect(Promotable::VERSION).to be_present
  end
end
