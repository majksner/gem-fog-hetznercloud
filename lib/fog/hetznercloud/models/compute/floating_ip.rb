# https://docs.hetzner.cloud/#resources-actions-get
module Fog
  module Hetznercloud
    class Compute
      class FloatingIp < Fog::Model
        identity :id

        attribute :description    # String
        attribute :ip             # String
        attribute :type           # ipv4|ipv6
        attribute :server         # id of server
        attribute :dns_ptr        # array of string
        attribute :home_location  # location object
        attribute :blocked        # boolean

        def type=(value)
          valid = ['ipv4', 'ipv6']
          if !valid.include? value
            raise Fog::Hetznercloud::Compute::InvalidInputError.new("ERROR: floating_ip type must be one of #{valid}")
          else
            attributes[:type] = value
          end
        end

        def description=(value)
          @lastdescription = attributes[:description]
          attributes[:description] = value
          if @lastdescription && @lastdescription != attributes[:description]
            @needsupdate = true
          else
            @needsupdate = false
          end
        end

        def home_location=(value)
          attributes[:home_location] = case value
                                        when Hash
                                          service.locations.new(value)
                                        when String
                                          service.locations.new(identity: value)
                                        else
                                          value
                                        end
        end

        def server=(value)
          attributes[:server] = case value
                                        when Hash
                                          service.servers.new(value)
                                        when Integer
                                          service.servers.get(value)
                                        else
                                          value
                                        end
        end

        def destroy
          requires :identity

          service.delete_floating_ip(identity)
          true
        end

        def save
          if persisted?
            reassign && unassign && update
          else
            create
          end
        end

        def assign(serverid)
          requires :identity
          if serverid.nil?
            body = {}

            if (floating_ip = service.floating_ip_unassign(identity, body).body['floating_ip'])
              merge_attributes(floating_ip)
              true
            else
              false
            end
          else
            body = {
              server: serverid,
            }

            if (floating_ip = service.floating_ip_assign_to_server(identity, body).body['floating_ip'])
              merge_attributes(floating_ip)
              true
            else
              false
            end
          end
        end

        def update_dns_ptr(newname)
          requires :identity

          body = {
            ip: ip,
            dns_ptr: newname,
          }

          if (floating_ip = service.floating_ip_update_dns_ptr(identity, body).body['floating_ip'])
            merge_attributes(floating_ip)
            true
          else
            false
          end
        end

        def unassign
          if !server.nil?
            assign(nil)
          end
        end

        private

        def create
          requires :type
          requires_one :home_location, :server

          options = {}
          options[:description] = description unless description.nil?
          options[:home_location] = home_location.identity unless home_location.nil?
          options[:server] = server.identity unless server.nil?

          if (floating_ip = service.create_floating_ip(type,options).body['floating_ip'])
            merge_attributes(floating_ip)
            true
          else
            false
          end
        end

        def update
          return true if !@needsupdate
          requires :identity, :description

          body = attributes.dup

          body[:description] = description

          if (floating_ip = service.update_floating_ip(identity, body).body['floating_ip'])
            merge_attributes(floating_ip)
            true
          else
            false
          end

        end

      end
    end
  end
end