# frozen_string_literal: true

module RemoteDevelopment
  # This module contains all messages for the Remote Development domain, both errors and domain events.
  # Note that we intentionally have not DRY'd up the declaration of the subclasses with loops and
  # metaprogramming, because we want the types to be easily indexable and navigable within IDEs.
  module Messages
    #---------------------------------------------------------------
    # Errors - message name should describe the reason for the error
    #---------------------------------------------------------------

    # License error
    LicenseCheckFailed = Class.new(Message)

    # Auth errors
    Unauthorized = Class.new(Message)

    # AgentConfig errors
    AgentConfigUpdateFailed = Class.new(Message)

    # Workspace errors
    WorkspaceUpdateFailed = Class.new(Message)

    #---------------------------------------------------------
    # Domain Events - message name should describe the outcome
    #---------------------------------------------------------

    # AgentConfig domain events
    AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound = Class.new(Message)
    AgentConfigUpdateSuccessful = Class.new(Message)

    # Workspace domain events
    WorkspaceUpdateSuccessful = Class.new(Message)
  end
end
