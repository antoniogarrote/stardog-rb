require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Integrity Constraints" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name, "icv.enabled" => true)
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should be able to add a ICV" do
    path_tbox = File.join(File.dirname(__FILE__), "data", "tbox.owl")
    result = @conn.add_icv(@db_name, path_tbox, "text/turtle")
    expect(result.status).to be_eql(200)
 
    result = @conn.list_icvs(@db_name)
    expect(result.body.index("owl#Class")).not_to be_nil
  end
 
  it "should remove ICVs" do
    path_tbox = File.join(File.dirname(__FILE__), "data", "tbox.owl")
    result = @conn.add_icv(@db_name, path_tbox, "text/turtle")
    puts result
    expect(result.status).to be_eql(200)
 
    result = @conn.list_icvs(@db_name)
    expect(result.body.index("owl#Class")).not_to be_nil
 
    result = @conn.remove_icv(@db_name, path_tbox, "text/turtle")
    expect(result.status).to be_eql(204)
 
    result = @conn.list_icvs(@db_name)
    expect(result.body.index("owl#")).to be_nil
  end
 
 
  it "should clear ICVs" do
    path_tbox = File.join(File.dirname(__FILE__), "data", "tbox.owl")
    result = @conn.add_icv(@db_name, path_tbox, "text/turtle")
    puts result
    expect(result.status).to be_eql(200)
 
    result = @conn.list_icvs(@db_name)
    expect(result.body.index("owl#Class")).not_to be_nil
 
    result = @conn.clear_icvs(@db_name)
    expect(result.status).to be_eql(200)
 
    result = @conn.list_icvs(@db_name)
    expect(result.body.index("owl#")).to be_nil
  end

# it "should be possible to convert ICVs into SPARQL queries" do
#    path_tbox = File.join(File.dirname(__FILE__), "data", "tbox.owl")
#    result = @conn.convert_icv(@db_name, path_tbox, "text/turtle")
#    puts "CONVERSION!!!"
#    puts result
#  end

#  it "should apply ICVs" do
#    path_tbox = File.join(File.dirname(__FILE__), "data", "tbox.owl")
#    path_abox = File.join(File.dirname(__FILE__), "data", "abox.owl",)
# 
#    puts "HERE..."
#    result = @conn.add_icv(@db_name, path_tbox, "text/turtle")
#    puts result
# 
#    result = @conn.add(@db_name, path_abox, nil, "text/turtle")
#    puts result
#  end
end
