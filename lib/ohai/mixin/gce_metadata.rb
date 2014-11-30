#
# Author:: Ranjib Dey (<dey.ranjib@gmail.com>)
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'net/http'
require 'socket'

require 'ohai/util/socket_helper'

module Ohai
  module Mixin
    module GCEMetadata
      include Ohai::Util::SocketHelper

      GCE_METADATA_ADDR = "metadata.google.internal" unless defined?(GCE_METADATA_ADDR)
      GCE_METADATA_URL = "/computeMetadata/v1beta1/?recursive=true" unless defined?(GCE_METADATA_URL)

      def can_metadata_connect?(host, port, timeout = 2)
        connected = tcp_port_open?(host, port, timeout)
        Ohai::Log.debug("can_metadata_connect? == #{connected}")
        connected
      end

      def http_client
        Net::HTTP.start(GCE_METADATA_ADDR).tap {|h| h.read_timeout = 6}
      end

      def fetch_metadata(id='')
        uri = "#{GCE_METADATA_URL}/#{id}"
        response = http_client.get(uri)
        return nil unless response.code == "200"

        if json?(response.body)
          data = StringIO.new(response.body)
          parser = FFI_Yajl::Parser.new
          parser.parse(data)
        elsif  has_trailing_slash?(id) or (id == '')
          temp={}
          response.body.split("\n").each do |sub_attr|
            temp[sanitize_key(sub_attr)] = fetch_metadata("#{id}#{sub_attr}")
          end
          temp
        else
          response.body
        end
      end

      def json?(data)
        data = StringIO.new(data)
        parser = FFI_Yajl::Parser.new
        begin
          parser.parse(data)
          true
        rescue FFI_Yajl::ParseError
          false
        end
      end

      def multiline?(data)
        data.lines.to_a.size > 1
      end

      def has_trailing_slash?(data)
        !! ( data =~ %r{/$} )
      end

      def sanitize_key(key)
        key.gsub(/\-|\//, '_')
      end
    end
  end
end
