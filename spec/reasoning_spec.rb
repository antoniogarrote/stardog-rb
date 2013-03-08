require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Reasoning examples" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name)

    path_tbox = File.join(File.dirname(__FILE__), "data", "tbox.owl")
    path_abox = File.join(File.dirname(__FILE__), "data", "abox.owl",)
    @conn.add(@db_name, path_tbox, nil, "text/turtle")
    @conn.add(@db_name, path_abox, nil, "text/turtle")
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should be able to query the database" do
    results = @conn.query(@db_name, "select ?c where { ?c a <http://example.com/test/Organization> }")

    data = results.body["results"]["bindings"]
    expect(data.length).to be_eql(0)     
     
    @conn_reasoning = stardog("http://localhost:5822/", :user => "admin", :password => "admin", :reasoning => "QL")
    results = @conn_reasoning.query(@db_name, "select ?c where { ?c a <http://example.com/test/Organization> }")
     
    data = results.body["results"]["bindings"]
    expect(data.length).to be_eql(1)
    
    expect(@conn_reasoning.consistent?(@db_name)).to be_true
  end

  it "should be able to detect inconsistencies" do
    path_tbox = File.join(File.dirname(__FILE__), "data", "inconsistent_tbox.owl")
    @conn.add(@db_name, path_tbox, nil, "text/turtle")

    @conn_reasoning = stardog("http://localhost:5822/", :user => "admin", :password => "admin", :reasoning => "QL")
    expect(@conn_reasoning.consistent?(@db_name)).to be_false
  end

end
