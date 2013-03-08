require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Getting the DB info" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name)
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should return a non empty response when requesting DB info" do
    info = @conn.db_options(@db_name, ["database.name", "icv.enabled"])
    expect(info.body.raw_json.keys).to_not be_empty
    expect(info.body.raw_json.keys.length).to be_eql(2)
    expect(info.body["database.name"]).to be_eql(@db_name)
    expect(info.body["icv.enabled"]).to be_false
  end

  it "should return a non empty response by default" do
    info = @conn.db_options(@db_name)
    expect(info.body.raw_json.keys).to_not be_empty
  end
end
