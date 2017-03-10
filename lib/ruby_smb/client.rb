module RubySMB

  # Represents an SMB client capable of talking to SMB1 or SMB2 servers and handling
  # all end-user client functionality.
  class Client
    require 'ruby_smb/client/negotiation'

    include RubySMB::Client::Negotiation

    # The Default SMB1 Dialect string used in an SMB1 Negotiate Request
    SMB1_DIALECT_SMB1_DEFAULT = "NT LM 0.12"
    # The Default SMB2 Dialect string used in an SMB1 Negotiate Request
    SMB1_DIALECT_SMB2_DEFAULT = "SMB 2.002"
    # Dialect value for SMB2 Default (Version 2.02)
    SMB2_DIALECT_DEFAULT = 0x0202


    # The dispatcher responsible for sending packets
    # @!attribute [rw] dispatcher
    #   @return [RubySMB::Dispatcher::Socket]
    attr_accessor :dispatcher

    # The domain you're trying to authenticate to
    # @!attribute [rw] domain
    #   @return [String]
    attr_accessor :domain

    # The local workstation to pretend to be
    # @!attribute [rw] local_workstation
    #   @return [String]
    attr_accessor :local_workstation

    # The NTLM client used for authentication
    # @!attribute [rw] ntlm_client
    #   @return [String]
    attr_accessor :ntlm_client

    # The password to authenticate with
    # @!attribute [rw] password
    #   @return [String]
    attr_accessor :password

    # Whether or not the Server requires signing
    # @!attribute [rw] signing_enabled
    #   @return [Boolean]
    attr_accessor :signing_required

    # Whether or not the Client should support SMB1
    # @!attribute [rw] smb1
    #   @return [Boolean]
    attr_accessor :smb1

    # Whether or not the Client should support SMB2
    # @!attribute [rw] smb2
    #   @return [Boolean]
    attr_accessor :smb2

    # The username to authenticate with
    # @!attribute [rw] username
    #   @return [String]
    attr_accessor :username

    # @param dispatcher [RubySMB::Dispacther::Socket] the packet dispatcher to use
    # @param smb1 [Boolean] whether or not to enable SMB1 support
    # @param smb2 [Boolean] whether or not to enable SMB2 support
    def initialize(dispatcher, smb1: true, smb2: true, username:,password:, domain:nil, local_workstation:'')
      raise ArgumentError, 'No Dispatcher provided' unless dispatcher.kind_of? RubySMB::Dispatcher::Base
      if smb1 == false && smb2 == false
        raise ArgumentError, 'You must enable at least one Protocol'
      end
      @dispatcher        = dispatcher
      @domain            = domain
      @local_workstation = local_workstation
      @password          = password.encode("utf-8")
      @signing_required  = false
      @smb1              = smb1
      @smb2              = smb2
      @username          = username.encode("utf-8")

      @ntlm_client = Net::NTLM::Client.new(
        @username,
        @password,
        workstation: @local_workstation,
        domain: @domain
      )
    end

    # Handles the entire SMB Multi-Protocol Negotiation from the
    # Client to the Server. It sets state on the client appropriate
    # to the protocol and capabilites negotiated during the exchange.
    #
    # @return [void]
    def negotiate
      raw_response    = negotiate_request
      response_packet = negotiate_response(raw_response)
      parse_negotiate_response(response_packet)
    end

    def ntlmssp_negotiate
      type1_message = ntlm_client.init_context
      packet = RubySMB::SMB1::Packet::SessionSetupRequest.new
      packet.set_type1_blob(type1_message)
      packet.parameter_block.max_buffer_size = 4356
      packet.parameter_block.max_mpx_count = 50
      packet.smb_header.flags2.extended_security = 1

      dispatcher.send_packet(packet)
    end



  end
end
