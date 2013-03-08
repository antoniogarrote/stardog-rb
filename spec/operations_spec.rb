require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Getting and using operations outside transactions" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name)
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should be able to query the database" do
    a_triple = '<http://localhost/publications/articles/Journal1/1940/Article2> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject"^^<http://www.w3.org/2001/XMLSchema#string> .'
    result = @conn.with_transaction(@db_name) do |txID|
      response = @conn.add_in_transaction(@db_name, txID, a_triple)
      expect(response.status).to be_eql(200)
    end
    expect(result).to be_true
    
    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].first["s"]["value"]).to be_eql("http://localhost/publications/articles/Journal1/1940/Article2")
  end
  
  
  it "should be able get a transaction and add and remove a triple" do
    a_triple = '<http://localhost/publications/articles/Journal1/1940/Article2> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject"^^<http://www.w3.org/2001/XMLSchema#string> .'
    response = @conn.add(@db_name, a_triple)
    expect(response).to be_true
    
    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].first["s"]["value"]).to be_eql("http://localhost/publications/articles/Journal1/1940/Article2")
    
    response = @conn.remove(@db_name, a_triple)
    expect(response).to be_true
    
    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(0)
  end
  
  it "should be possible to add and remove triples directly from a file on disk" do
    path = File.join(File.dirname(__FILE__), "data", "api_tests.nt")
    expect(File.exists?(path)).to be_true
    response = @conn.add(@db_name, path)    
    
    results = @conn.query(@db_name, "select ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(33)
    
    response = @conn.remove(@db_name, path)
    results = @conn.query(@db_name, "select ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(0)
  end
  
  it "should be possible to add triples directly from a remote URL" do
    URL = "http://dbpedia.org/data/The_Lord_of_the_Rings"
    
    response = @conn.add(@db_name, URL, nil, "application/rdf+xml")    
    
    results = @conn.query(@db_name, "select ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["results"]["bindings"].length>0).to be_true
    
    response = @conn.remove(@db_name, URL, nil, "application/rdf+xml")    
    
    results = @conn.query(@db_name, "select ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["results"]["bindings"].length).to be_eql(0)
  end
  
  it "should be possible to add and remove triples to an specific graph context" do
    a_triple1 = '<http://localhost/publications/articles/Journal1/1940/Article1> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject 1"^^<http://www.w3.org/2001/XMLSchema#string> .'
    a_triple2 = '<http://localhost/publications/articles/Journal1/1940/Article2> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject 2"^^<http://www.w3.org/2001/XMLSchema#string> .'
    context1 = "test:graph1"
    context2 = "test:graph2"
    result = @conn.with_transaction(@db_name) do |txID|
      response = @conn.add_in_transaction(@db_name, txID, a_triple1,context1)
      expect(response.status).to be_eql(200)
      response = @conn.add_in_transaction(@db_name, txID, a_triple2,context2)
      expect(response.status).to be_eql(200)
    end
    expect(result).to be_true
    
    results = @conn.query(@db_name, "select ?g ?s where { graph ?g { ?s ?p ?o } }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["g","s"])
    data = results.body["results"]["bindings"].inject({}){|a,b| a[b["g"]["value"]] = b["s"]["value"]; a}
    expect(data[context1]).to be_eql("http://localhost/publications/articles/Journal1/1940/Article1")
    expect(data[context2]).to be_eql("http://localhost/publications/articles/Journal1/1940/Article2")
    
    result = @conn.with_transaction(@db_name) do |txID|
      response = @conn.remove_in_transaction(@db_name, txID, a_triple2,context2)
      expect(response.status).to be_eql(200)
    end
    
    results = @conn.query(@db_name, "select ?g ?s where { graph ?g { ?s ?p ?o } }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["g","s"])
    data = results.body["results"]["bindings"].inject({}){|a,b| a[b["g"]["value"]] = b["s"]["value"]; a}
    expect(data[context1]).to be_eql("http://localhost/publications/articles/Journal1/1940/Article1")
    expect(data[context2]).to be_nil
    
  end

  it "should allow to pass limit and offset parameters to queries" do
    a_triple1 = '<http://localhost/publications/articles/Journal1/1940/Article1> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject 1"^^<http://www.w3.org/2001/XMLSchema#string> .'
    a_triple2 = '<http://localhost/publications/articles/Journal1/1940/Article2> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject 2"^^<http://www.w3.org/2001/XMLSchema#string> .'



    result = @conn.with_transaction(@db_name) do |txID|
      response = @conn.add_in_transaction(@db_name, txID, a_triple1)
      expect(response.status).to be_eql(200)
      response = @conn.add_in_transaction(@db_name, txID, a_triple2)
      expect(response.status).to be_eql(200)
    end

    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }", :limit => 1, :offset => 0)
    puts "RESULTS LIMIT OFFSET"
    puts results.inspect
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(1)


    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }", :limit => 1, :offset => 1)
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(1)


    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }", :limit => 1, :offset => 5)
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(0)


    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }", :limit => 0, :offset => 0)
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(0)

    results = @conn.query(@db_name, "select distinct ?s where { ?s ?p ?o }")
    expect(results.status).to be_eql(200)
    expect(results.body["head"]["vars"]).to be_eql(["s"])
    expect(results.body["results"]["bindings"].length).to be_eql(2)
    
  end
end
