# stardog-rb

HTTP Bindings for the [Stardog](http://stardog.com/) RDF database.

## Installation

    gem install stardog-rb

## Requiring
```ruby
    require 'stardog'
   
    include Stardog
```
## Establishing a Connection

You can use the *stardog* function to open a connection. It accepts the endpoint URL as well as a hash of options: user, password, reasoning, etc...
```ruby
    sd = stardog("http://localhost:5822/", 
                 :user => "admin", 
                 :password => "admin", 
                 :reasoning => "QL")
```
## Creating and droping a  database
```ruby
    sd.create_db(db_name)

    sd.drop_db(db_name)
```
## Adding and removing triples

Triples can be added from a text string, a file system path or a remote URL:
```ruby
    triples = ['<http://localhost/publications/articles/Journal1/1940/Article2>',
               '<http://purl.org/dc/elements/1.1/subject>',
               '"A very interesting subject"^^<http://www.w3.org/2001/XMLSchema#string>.'].join(' ')
    sd.add(db_name, triples)

    path = File.join(File.dirname(__FILE__), "data", "api_tests.nt")
    sd.add(db_name, path)

    url = "http://dbpedia.org/data/The_Lord_of_the_Rings"
    db.add(db_name, url, nil, "application/rdf+xml")    
```
Removing triples can be accomplished with the symmetrical *remove* function:

```ruby
    db.remove(@db_name, url, nil, "application/rdf+xml")    
```
Triples can be inserted inside a named graph passing a third argument to the *add* and *remove* methods.     
```ruby
    db.add(db_name, a_triple2,"my:graph")
```
All operations will run inside a single Stardog transaction.

## Transactions

Transactions can be executed using the *with_transaction* helper method that will take care of committing if the transaction is successful or rolling back the transaction if an exception is raised:

```ruby
    result = sd.with_transaction(db_name) do |txID|
      sd.add_in_transaction(db_name, txID, a_triple1)
      sd.add_in_transaction(db_name, txID, a_triple2)
    end
```

The methods *add_in_transaction* and *remove_in_transaction* have the same interface as the *add* and *remove* functions but also accepting a transaction ID.
The previous code is analogous to this version using the *begin* and *commit* methods:

```ruby
    result = begin
      txID = begin(db_name)
      sd.add_in_transaction(db_name, txID, a_triple1)
      sd.add_in_transaction(db_name, txID, a_triple2)
      commit(db_name, txID)
      true
    rescue Exception => ex
      rollback(db_name, txID)
      false
    end    
```

## Queries

Queries can be issued using the *query* method. Results will be returned as a *LinkedJSON* that can be processed as a regular Hash.

```ruby
    results = conn.query(db_name, "select ?g ?s where { graph ?g { ?s ?p ?o } }")

    results.body["head"]["vars"] # > ["g","s"]
    results.body["results"]["bindings"].inject({}) do |a,b| 
      a[b["g"]["value"]] = b["s"]["value"]; a
    end # > { graph_uri => uri }
```
Options *limit*, *offset* and *base_uri* can be passed to the query method as a hash of options.

Queries can be run inside a transaction using the *query_in_transaction* variation of the *query* method:

```ruby
    db.with_transaction(db_name) do |txID|
      results = query_in_transaction(db_name, txID, query)
    end
```
## Reasoning

To enable reasoning in queries, the *reasoning* option with the right reasoning level (QL, RDFS, EL...) must be provided.
Inferred results will be obtained when queries are issued.

For example, for the database:

    @prefix : <http://example.com/test/> .
    @prefix owl: <http://www.w3.org/2002/07/owl#> .
    @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
     
    :Company a rdfs:Class .
    :Organization a rdfs:Class .
    :Company rdfs:subClassOf :Organization .

    :clark_and_parsia rdf:type :Company .


The following query will not return any result:
```ruby
    @conn = stardog("http://localhost:5822/", :user => "admin", :password => "admin")
    results = @conn.query(@db_name, "select ?c where { ?c a <http://example.com/test/Organization> }")

    data = results.body["results"]["bindings"]
    expect(data.length).to be_eql(0)     
```
After setting the connection level in the connection string, inferred results will be returned
```ruby
    @conn_reasoning = stardog("http://localhost:5822/", :user => "admin", :password => "admin", :reasoning => "QL")
    results = @conn_reasoning.query(@db_name, "select ?c where { ?c a <http://example.com/test/Organization> }")
     
    data = results.body["results"]["bindings"]
    expect(data.length).to be_eql(1) # > c => ':clark_and_parsia'
```
Consistency of the database can be checked using the *consistent?* method in a reasoning enabled connection:
```ruby
    @conn_reasoning.consistent?(@db_name) # > true
```
Refer to Stardog's documentation about reasoning (http://stardog.com/docs/owl2/#reasoning) for more details about TBox extraction, different reasoning levels, etc.

## Author and contact:

Antonio Garrote (antoniogarrote@gmail.com)

## Notes

This implementation is a work in progress. Some functionality has not been yet wrapped.

You can turn on debugging by setting the *STARDOG_RB_DEBUG* environment variable to true.

Specs can be run using RSpec.