require 'rspec'
require 'win32/xpath'

# Just run a simple RSpec test to verify C extension compatibility
RSpec.describe 'C Extension Test' do
  it "works with basic path expansion" do
    expect(File.expand_path('C:/temp')).to eq('C:/temp')
  end
  
  it "handles empty paths" do
    expect(File.expand_path('')).to be_a(String)
  end
  
  it "handles tilde expansion" do
    result = File.expand_path('~')
    expect(result).to be_a(String)
    expect(result).to start_with('C:/')
  end
end
