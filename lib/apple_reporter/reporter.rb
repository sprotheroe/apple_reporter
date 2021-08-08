module AppleReporter
  class Reporter
    ENDPOINT = 'https://reportingitc-reporter.apple.com/reportservice'
    GZIP_MIMETYPE = '1f8b0800000000000000'.freeze
    #
    # Usage:
    # reporter = Apple::Reporter::Sale.new(user_id: 'iscreen', access_token: 'secret', account: 'myAccount')
    #
    def initialize(config = {})
      @config = {
        sales_path: '/sales/v1',
        finance_path: '/finance/v1',
        mode: 'Robot.XML',
        version: '1_0',
        decompress: true
      }.merge(config)
    end

    private

    def fetch(api_path, params, url_params=nil)
      headers = {
        'Content-Type' => 'application/x-www-form-urlencoded'
      }
      payload = {
        userid: @config[:user_id],
        accesstoken: @config[:access_token],
        version: @config[:version],
        mode: @config[:mode],
        queryInput: "[p=Reporter.properties, #{params}]"
      }
      payload[:account] = @config[:account] if @config[:account]
      payload[:password] = @config[:password] if @config[:password]
      verify_ssl = true # set false as workaround when Apple cert expired
      response = nil
      if false
        response = RestClient::Resource.new(
          "#{ENDPOINT}#{api_path}",
          headers: headers,
          verify_ssl: verify_ssl
        ).post("jsonRequest=#{payload.to_json}#{url_params}")
      else
        response = RestClient::Request.execute(method: :post,
                                               url: "#{ENDPOINT}#{api_path}",
                                               headers: headers,
                                               verify_ssl: verify_ssl,
                                               timeout: 300, # 5 minute timeout
                                               payload: "jsonRequest=#{payload.to_json}#{url_params}")
      end
      handle_response(@config[:mode], response)
    rescue RestClient::ExceptionWithResponse => err
      if err.response
        handle_response(@config[:mode], err.response)
      else
        raise err
      end
    end

    #
    def handle_response(mode, response)
      if response.code == 200
        if response.headers[:content_type] == 'application/a-gzip'
          if @config[:decompress]
            decompress_gzip(response.body)
          else
            {filename: response.headers[:filename], content: response.body}
          end
        else
          handle_response_body_with_mode(response.body, mode)
        end
      else
        handle_response_body_with_mode(response.body, mode)
      end
    end

    def handle_response_body_with_mode(body, mode)
      if mode =~ /robot\.xml/i
        Hash.from_xml(body)
      else
        body
      end
    end

    def decompress_gzip(compress_string)
      buffer = []
      chunks = compress_string.unpack('H*').first.split(GZIP_MIMETYPE)
      if chunks.length == 1
        buffer << ActiveSupport::Gzip.decompress([chunks.first].pack('H*'))
      else
        chunks.reject(&:empty?).each do |chunk|
          buffer << Zlib::GzipReader.new(StringIO.new([GZIP_MIMETYPE + chunk].pack('H*'))).read
        end
      end
      buffer.join
    end
  end
end
