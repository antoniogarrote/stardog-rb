require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Set DB Options Test Suite" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name)
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should set the options of an DB" do
    @conn.offline_db(@db_name)
    results = @conn.set_db_options(@db_name, {"icv.enabled" => false, "search.enabled" => true})
    info = @conn.db_options(@db_name, ["search.enabled", "icv.enabled"])
    expect(info.body.raw_json.keys).to_not be_empty
    expect(info.body.raw_json.keys.length).to be_eql(2)
    expect(info.body["search.enabled"]).to be_true
    expect(info.body["icv.enabled"]).to be_false
  end

end
