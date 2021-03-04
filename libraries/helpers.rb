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
      shell_out('lspci').stdout.match?(/VGA.*NVIDIA/)
    end

    # Determines if an NVIDIA card GRID is detected on the system
    # The model is the one in AWS nodes
    #
    # @return [Boolean]
    def has_nvidia_grid_support?
      shell_out('lspci').stdout.match?(/.*NVIDIA.*GRID/)
    end
  end
end

Chef::DSL::Recipe.include ::OSRFJenkinsAgent::Helpers
Chef::Resource.include ::OSRFJenkinsAgent::Helpers
