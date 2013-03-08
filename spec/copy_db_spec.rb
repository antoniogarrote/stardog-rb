require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Copy DBs Test Suite" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name)
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should not copy an online DB" do
    db_copy_name = "#{@db_name}_copy"
    expect(@conn.copy_db(@db_name,db_copy_name).status).to eq(500)    
  end

  it "should copy an offline DB" do
    db_copy_name = "#{@db_name}_copy"
    @conn.offline_db(@db_name)
    expect(@conn.copy_db(@db_name,db_copy_name).status).to eq(200)    
    @conn.drop_db(db_copy_name)
  end

end
