require 'rest-client'
require 'json'
require 'tempfile'
require 'debugger'

module Stardog

  # Current version of the library.
  VERSION = "0.0.1"

  DEBUG = true

  class StardogResponse
    attr_reader :status, :body

    def initialize(status, body)
      @status = status
      @body = body
    end

    def success?
      @status.to_s =~ /^2\d{2}$/
    end

    def to_s
      "#{status}\n--------\n#{body}\n--------\n"
    end
  end

  class LinkedJSON

    def initialize(attributes = {})
      @attributes = attributes
    end

    def get(key)
      @attributes[key]
    end

    def set(key,value)
      @attributes[key] = value
    end

    def [](arg) 
      @attributes[arg]
    end

    def []=(arg,value)
      @attributes[arg] = value
    end

    def raw_json
      @attributes
    end

    def to_s
      @attributes.to_json
    end
  end


  class Connection

    attr_accessor :endpoint, :reasoning, :credentials
    
    def initialize
      # By default (for testing)
      @endpoint = 'http://localhost:5822/'
      @credentials = {:user =>'admin', :password => 'admin'}
    end

    def set_credentials(username, password)
      @credentials = {:user => username, :password => password}
    end


    def get_property(database, uri, property)
      str_query = 'select ?val where { '+ uri +' '+ property +' ?val }' 

      json_res = query(database, str_query).body

      if (json_res["results"] && json_res["results"]["bindings"].length > 0)
				json_res["results"]["bindings"].first["val"]["value"]
      else
        nil
      end
    end

    def get_db(database)
      http_request("GET", database)
    end

    def get_db_size(database)
      http_request("GET", "#{database}/size")      
    end

    def query(database, query, options = {})
      base_uri = options[:base_uri]
      limit = options[:limit] 
      offset = options[:offset] 
      accept = options[:accept]

      accept_header = accept ? accept : 'application/sparql-results+json'
      options = {
        :query => query
      }

      options[:base_uri] = base_uri if base_uri
      options[:limit] = limit if limit
      options[:offset] = offset if offset

      http_request("GET", "#{database}/query", accept, options)
    end

    def add(database, body, graph_uri=nil, content_type="text/plain")
      with_transaction(database) do |txId|
        add_in_transaction(database, txId, body, graph_uri, content_type)
      end
    end

    def remove(database, body, graph_uri=nil, content_type="text/plain")
      with_transaction(database) do |txId|
        remove_in_transaction(database, txId, body, graph_uri, content_type)
      end
    end

    def query_graph(database, query, base_uri, options)
      base_uri = options[:base_uri]
      limit = options[:limit] 
      offset = options[:offset] 
      accept = options[:accept]

      accept_header = accept ? accept : 'application/ld+json'
      options = {
        :query => query
      }

      options[:base_uri] = base_uri if base_uri
      options[:limit] = limit if limit
      options[:offset] = offset if offset

      http_request("GET", "#{database}/query", accept, options)
    end

    def query_explain(database, query, options = {})
      base_uri = options[:base_uri]
      
      options = {
        :query => query
      }

      options[:base_uri] = base_uri if base_uri

      http_request("GET", "#{database}/explain", "text/plain", options)
    end

    ################
    # Transactions
    ################

    def begin(database)
      result = http_request("POST", "#{database}/transaction/begin", "text/plain", "")
      if(result.status == 200)
        result.body
      else
        raise Exception.new("Error beginning transaction #{result}")
      end
    end


    def commit(database, txID)
      http_request("POST", "#{database}/transaction/commit/#{txID}", "text/plain", "")
    end

    def rollback(database, txID)
      http_request("POST", "#{database}/transaction/rollback/#{txID}", "text/plain", "")
    end

    # Initiates a transaction and handles the commit or rollback of it.
    # if an exception is raised the transaction will be committed.
    # It accepts a block that will receive a transaction ID as argument.
    # - db_name
    # - transaction block
    def with_transaction(db_name)
      begin
        txID = self.begin(db_name)
        yield txID
        commit(db_name,txID)
        true
      rescue Exception => ex
        debug "* Error in transaction #{txID}"
        debug ex.message
        debug ex.backtrace.join("\n")
        rollback(db_name, txID)
        false
      end
    end

    def query(database, query, options = {})
      base_uri = options[:base_uri]
      limit = options[:limit] 
      offset = options[:offset] 
      accept = options[:accept]
      ask_request = options.delete(:ask)

      accept = 'text/boolean' if(ask_request)
      accept_header = accept ? accept : 'application/sparql-results+json'
      
      options = {
        :query => query
      }

      options[:base_uri] = base_uri if base_uri
      options[:limit] = limit if limit
      options[:offset] = offset if offset

      http_request("GET", "#{database}/query", accept_header, options, nil, (ask_request ? false: true))
    end

    def query_in_transaction(database, txID, query, options = {})
      base_uri = options[:base_uri]
      limit = options[:limit] 
      offset = options[:offset] 
      accept = options[:accept]
      ask_request = options.delete(:ask)

      accept = 'text/boolean' if(ask_request)
      accept_header = accept ? accept : 'application/sparql-results+json'
      
      options = {
        :query => query
      }

      options[:base_uri] = base_uri if base_uri
      options[:limit] = limit if limit
      options[:offset] = offset if offset

      http_request("GET", "#{database}/#{txID}/query", accept_header, options, nil, (ask_request ? false: true))
    end

    def add_in_transaction(database, txID, body, graph_uri=nil, content_type="text/plain")
      options = nil
      options = {"graph_uri" => graph_uri} if graph_uri

      if(File.exists?(body))
        body = File.open(body,"r").read
      end
      http_request("POST", "#{database}/#{txID}/add", "*/*", options, body, false, content_type, nil)
    end

    def remove_in_transaction(database, txID, body, graph_uri=nil, content_type="text/plain")
      options = nil
      options = {"graph_uri" => graph_uri} if graph_uri

      if(File.exists?(body))
        body = File.open(body,"r").read
      end
      http_request("POST", "#{database}/#{txID}/remove", "text/plain", options, body, false, content_type, nil)
    end

    def clear_db(database, txId, graph_uri = nil)
      options = nil
      options = {"graph-uri" => graph_uri} if graph_uri

      http_request("POST", database + "/" + txId + "/clear", "text/plain", options);
    end

    ################    
    # Reasoning
    ################
    
    def reasoning_explain(database, axioms, options = {})
      content_type = options[:content_type] || "text/plain"
      txID = options[:tx_id]

      url = "#{database}/reasoning"
      url = "#{url}/#{txID}" if txID

      url = "#{url}/explain"

      http_request("POST", url, "application/x-turtle", {}, axioms, false, content_type)
    end


    def consistent?(database, accept, options = {})
      options = nil
      options = {"graph-uri" => options[:graph_uri]} if options[:graph_uri]
      
      res = http_request("GET", "#{database}/reasoning/consistency", "text/boolean", options)
      (res == "true" ? true : false)
    end

    #######################    
    # Database Operations
    #######################    

    # List all available databases
    def list_dbs
      http_request("GET", "admin/databases", "application/json", "")
    end


    # Get configuration properties for the database.
    # The lis of properties can be found here: http://stardog.com/docs/admin/#admin-db
    # By default, "database.name", "icv.enabled", "search.enabled", "database.online", "index.type" properties a requested.
    def db_options(db_name, options = ["database.name", "icv.enabled", "search.enabled", "database.online", "index.type"])
      http_request("PUT", "admin/databases/#{db_name}/options", "application/json", {}, options.inject({}){|ac,i| ac[i]=""; ac})
    end

    # Set properties for a DB.
    # options and values must be passed as the second argument to the method.
    # DB must be offline before being setting the new values.
    # The lis of properties can be found here: http://stardog.com/docs/admin/#admin-db
    # - db_name
    # - options: hash with properties and values.
    def set_db_options(db_name, options)
      http_request("POST", "admin/databases/#{db_name}/options", "application/json", {}, options)
    end

    # Copy a database
    # Copies a database. The source database must be offline.
    # The target database will be created.
    def copy_db(db_source,db_target)
      http_request("PUT", "admin/databases/#{db_source}/copy", "application/json", { "to" => db_target })
    end

    # Creates a new database
    def create_db(dbname, creation_options={})
      options = creation_options[:options] || {}
      files = creation_options[:files] ||= []
      if(files.empty?)
        http_request("POST", "admin/databases", "text/plain", {}, {:dbname => dbname, :options => options, :files => files}.to_json, true, "application/json", true)
      else
        f = Tempfile.new("stardog_rb_#{Time.now.to_i}")
        f << "{\"dbname\":\"#{dbname}\",\"options\":#{options.to_json},\"files\":[{"
        files.each_with_index do |datafile,i|
          f << "\"name\":\"#{File.basename(datafile)}\", \"content\":"
          f << File.open(datafile,"r").read.chomp.to_json
          f << "," if i != (files.length - 1)
        end
        f << "}]}"
        f.flush
        f.close
        puts `cat #{f.to_path}`
        http_request("POST", "admin/databases", "text/plain", {}, File.new(f.path), true, "application/json", true)                  
      end
    end

    # Drops an existent database.
    def drop_db(dbname)
      http_request("DELETE", "admin/databases/#{dbname}", "application/json", "")      
    end


    # Sets database offline.
    # * strategy_op: 'WAIT' | 'NO_WAIT', default 'WAIT'.
    # * timeout: timeout in ms, default 3 ms.
    def offline_db(dbname, strategy_op = 'WAIT', timeout = 3)
      http_request("PUT", "admin/databases/#{dbname}/offline", "application/json", {}, { "strategy" => strategy_op, "timeout" => timeout })
    end

    # Sets database offline.
    # * strategy_op: 'WAIT' | 'NO_WAIT', default 'WAIT'.
    def online_db(dbname, strategy_op)
      http_request("PUT", "admin/databases/#{dbname}/online", "application/json", {}, { "strategy" => strategy_op })
    end

    ################    
    # Admin
    ################
    def clear_stardog
      list_dbs.body["databases"].each do |db|
        drop_db db
      end
    end

    def shutdown_server()
      http_request("POST", "admin/shutdown", "application/json")
    end

    private

    def http_request(method, resource, accept = "*/*", params = {}, msg_body = nil, is_json_body = true, content_type = nil, multipart = false)
      url = "#{@endpoint}#{resource}"
      if(params.is_a?(Hash) && params.keys.length > 0)
        params = params.keys.map{|k| "#{CGI::escape(k.to_s)}=#{CGI::escape(params[k].to_s)}" }.join('&')
        url = "#{url}?#{params}"
      elsif(params.is_a?(String) && params != "")
        url = "#{url}?#{params}"        
      end
      arguments = {
        :method => method.to_s.downcase.to_sym,
        :url => url,
        :headers => {:accept => accept},
      }

      arguments[:headers]['SD-Connection-String'] = @reasoning if @reasoning

      arguments.merge!(credentials) if credentials

      arguments[:payload] = msg_body if msg_body

      if(is_json_body)
        arguments[:headers][:content_type] = "application/json"
        arguments[:payload] = arguments[:payload].to_json if arguments.to_json != "" && !multipart
      else
        arguments[:headers][:content_type] = content_type
      end

      file = nil
      if(multipart) 

        unless(arguments[:payload].is_a?(File))
          file = Tempfile.new("stardog_rb_#{Time.now.to_i.to_s}")
          file.write(arguments[:payload])
          file.close
          arguments[:payload] = File.new(file)
          arguments[:multipart] = true
        end
        arguments[:payload] = {
          :file => arguments[:payload],
          :multipart => true
        }
      end
      
      
      debug "ARGUMENTS:"
      debug arguments.inspect
      response = RestClient::Request.execute(arguments)
      debug "RESPONSE:"
      debug response.code
      debug "---"
      debug response.headers
      debug "---"
      debug response.body
      debug "-----------------------\n"

      if response.code.to_s =~ /^2\d{2}$/
        if response.headers[:content_type] && response.headers[:content_type].index("json")
          json_data = JSON.parse(response.body)
          
          result = if json_data.is_a?(Array)
                     json_data.inject([]) { |ac, i| ac << i if(i["@id"] || i["@context"]); ac }
                   else
                     LinkedJSON.new(json_data)
                   end
          StardogResponse.new(response.code, result)
        elsif response.headers[:content_type] && response.headers[:content_type].index("application/xml")
          StardogResponse.new(response.code, Nokogiri::XML(response.body))
        else
          StardogResponse.new(response.code, response.body)
        end
      else
        StardogResponse.new(response.code, response.body)
      end

    rescue => exception
      if(exception.respond_to?(:response))
        debug "RESPONSE:"
        debug exception.response.code
        debug "---"
        debug exception.response.headers
        debug "---"
        debug exception.response.body
        debug "-----------------------\n"

        StardogResponse.new(exception.response.code, exception.response.body)
      else
        raise exception
      end
    ensure
      file.unlink unless file.nil?
    end # end of http_request

    def debug(msg)
      puts msg if Stardog::DEBUG
    end

  end # end of Connection


  # Returns a connection
  def stardog(endpoint = nil, options = {})
    connection = Connection.new
    connection.endpoint = endpoint if endpoint
    connection.reasoning = options[:reasoning] if options[:reasoning]
    connection.set_credentials(options[:user], options[:password]) if options[:user] && options[:password]

    connection
  end

end
