require 'spec_helper'

describe 'squid3', :type => :class do
    let :facts do
        {
            :lsbdistrelease => '14.04',
            :lsbdistid => 'Ubuntu',
        }
    end
    it 'should have squid' do
        contain_package('squid3').with_ensure('present')
        contain_service('squid3').with_ensure('running')

        should contain_file('/etc/squid3/squid.conf').with({
            'ensure' => 'present',
            'mode'   => '0444',
            'owner'  => 'root',
            'group'  => 'root',
        })

        should contain_file('/etc/logrotate.d/squid3').with({
            'ensure' => 'present',
            'mode'   => '0444',
            'owner'  => 'root',
            'group'  => 'root',
        })
    end
end
