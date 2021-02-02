#
# Copyright:: 2020, Open Source Robotics Foundation.
#
#
module OSRFJenkinsAgent
  module Helpers
    # Determines if an NVIDIA card is detected on the system
    #
    # @return [Boolean]
    def has_nvidia_support?
      shell_out!('lspci').include?('VGA.*NVIDIA')
    end
  end
end

Chef::DSL::Recipe.include ::OSRFJenkinsAgent::Helpers
Chef::Resource.include ::OSRFJenkinsAgent::Helpers
