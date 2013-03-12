require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Drop DBs Test Suite" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
  end

  after(:each) do
    @conn = nil
  end

  it "should not drop an non-existent DB" do
    expect(@conn.drop_db("nodeDB_drop").status).to eq(404)
  end

  it "should drop a just created database" do
    db_name = "nodeDB_#{Time.now.to_i}"
    db_copy_name = "#{db_name}_copy"
     
    begin
      @conn.create_db(db_name)
      expect(@conn.offline_db(db_name,"WAIT").status).to eq(200)
      expect(@conn.copy_db(db_name,db_copy_name).status).to eq(200)
      expect(@conn.online_db(db_name,"NO_WAIT").status).to eq(200)
    ensure
      expect(@conn.drop_db(db_copy_name).status).to eq(200)
      expect(@conn.drop_db(db_name).status).to eq(200)
    end
  end

end
