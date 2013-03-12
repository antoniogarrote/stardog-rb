require File.join(File.dirname(__FILE__), "helper")

include Stardog

describe "Getting and using transactions" do

  before(:each) do
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    @db_name = "nodeDB_#{Time.now.to_i}"
    @conn.create_db(@db_name)
  end

  after(:each) do
    @conn.drop_db(@db_name)
    @conn = nil
  end

  it "should be able get a transaction and add a triple" do
    a_triple = '<http://localhost/publications/articles/Journal1/1940/Article2> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject"^^<http://www.w3.org/2001/XMLSchema#string> .'
    result = @conn.with_transaction(@db_name) do |txID|
      response = @conn.add_in_transaction(@db_name, txID, a_triple)
      expect(response.status).to be_eql(200)
    end
    expect(result).to be_true

    result = @conn.with_transaction(@db_name) do |txID|
      results = @conn.query_in_transaction(@db_name, txID, "select distinct ?s where { ?s ?p ?o }")
      expect(results.status).to be_eql(200)
      expect(results.body["head"]["vars"]).to be_eql(["s"])
      expect(results.body["results"]["bindings"].first["s"]["value"]).to be_eql("http://localhost/publications/articles/Journal1/1940/Article2")
    end
    expect(result).to be_true
  end


  it "should be able to rollback a change in a transaction" do
    a_triple = '<http://localhost/publications/articles/Journal1/1940/Article2> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject"^^<http://www.w3.org/2001/XMLSchema#string> .'
    successful = nil
    begin
      @conn.with_transaction(@db_name) do |txID|
        response = @conn.add_in_transaction(@db_name, txID, a_triple)
        expect(response.status).to be_eql(200)

        raise Exception.new("Stop the transaction")
        successful = true
      end
    rescue Exception => ex
      successful = false
    end
    expect(successful).to be_false

    result = @conn.with_transaction(@db_name) do |txID|
      results = @conn.query_in_transaction(@db_name, txID, "select distinct ?s where { ?s ?p ?o }")
      expect(results.status).to be_eql(200)
      expect(results.body["head"]["vars"]).to be_eql(["s"])
      expect(results.body["results"]["bindings"].length).to be_eql(0)
    end
    expect(result).to be_true
  end

  it "should be able get a transaction and remove a triple" do
    a_triple = '<http://localhost/publications/articles/Journal1/1940/Article2> <http://purl.org/dc/elements/1.1/subject> "A very interesting subject"^^<http://www.w3.org/2001/XMLSchema#string> .'
    result = @conn.with_transaction(@db_name) do |txID|
      response = @conn.add_in_transaction(@db_name, txID, a_triple)
      expect(response.status).to be_eql(200)
    end
    expect(result).to be_true

    result = @conn.with_transaction(@db_name) do |txID|
      results = @conn.query_in_transaction(@db_name, txID, "select distinct ?s where { ?s ?p ?o }")
      expect(results.status).to be_eql(200)
      expect(results.body["head"]["vars"]).to be_eql(["s"])
      expect(results.body["results"]["bindings"].first["s"]["value"]).to be_eql("http://localhost/publications/articles/Journal1/1940/Article2")
    end
    expect(result).to be_true

    result = @conn.with_transaction(@db_name) do |txID|
      response = @conn.remove_in_transaction(@db_name, txID, a_triple)
      expect(response.status).to be_eql(200)
    end
    expect(result).to be_true

    result = @conn.with_transaction(@db_name) do |txID|
      results = @conn.query_in_transaction(@db_name, txID, "select distinct ?s where { ?s ?p ?o }")
      expect(results.status).to be_eql(200)
      expect(results.body["head"]["vars"]).to be_eql(["s"])
      expect(results.body["results"]["bindings"].length).to be_eql(0)
    end
    expect(result).to be_true
  end

end
