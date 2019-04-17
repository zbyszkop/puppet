Facter.add('raid') do
  confine :kernel => :linux
  # ref: http://pci-ids.ucw.cz/v2.2/pci.ids
  pci_ids = {
    '9005028f' => 'ssacli' # Smart Storage PQI 12G SAS/PCIe 3
  }
  setcode do
    raids = []

    File.open('/proc/bus/pci/devices').each do |line|
      words = line.split
      raids.push(pci_ids[words[1]]) if pci_ids.key?(words[1])
    end

    if FileTest.exist?('/proc/mdstat')
      IO.foreach('/proc/mdstat') do |x|
        if x =~ /md[0-9]+ : active/
          raids.push('md')
          break
        end
      end
    end

    if FileTest.exist?('/dev/cciss/') || FileTest.exist?('/sys/module/hpsa/')
      raids.push('hpsa') unless raids.include?('ssacli')
    end

    if FileTest.exist?('/dev/megadev0') ||
       Dir.glob('/sys/bus/pci/drivers/megaraid_sas/00*').length > 0 # rubocop:disable Style/NumericPredicate
      raids.push('megaraid')
    end

    if FileTest.exist?('/dev/mpt0') ||
       FileTest.exist?('/proc/scsi/mptsas/0')
      raids.push('mpt')
    end

    if FileTest.exist?('/dev/aac0')
      raids.push('aacraid')
    end

    if FileTest.exist?('/proc/scsi/scsi')
      IO.foreach('/proc/scsi/scsi') do |x|
        if x =~ /Vendor: 3ware/
          raids.push('3ware')
          break
        end
      end
    end

    supported_devs = ['aac', 'twe']
    dev_re = Regexp.new(/^\s*\d+\s+(\w+)/)
    IO.foreach('/proc/devices') do |x|
      m = x.match(dev_re)
      if m
        dev = m[1]
        raids.push(dev) if supported_devs.include?(dev)
      end
    end

    raids.sort.uniq
  end
end
