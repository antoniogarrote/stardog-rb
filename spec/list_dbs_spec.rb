require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Listing DBs Test Suite" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name)
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should contain the db previously loaded" do
    dbs = @conn.list_dbs.body["databases"]
    expect(dbs).to include(@db_name)
  end

end
