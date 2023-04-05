Ohai.plugin(:GPUDevices) do
  provides 'gpu_devices'

  def gpu_devices_from_lspci
    shell_out('lspci -vmm').stdout.split("\n\n").select do |pcidev|
      pcidev =~ /(?:3D|VGA)(?: compatible) controller/
    end.map do |gpudev|
      Mash.new.tap do |properties|
        gpudev.lines.map do |line|
          line.chomp!
          key, val = line.split(":\t")
          properties[key.downcase] = val
        end
      end
    end
  end

  collect_data(:linux) do
    gpu_devices Mash.new
    gpu_devices_from_lspci.each do |dev|
      gpu_devices[dev['slot']] = dev
    end
  end
end
