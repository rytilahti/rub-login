#!/usr/bin/env ruby
require 'rubygems'
require 'mechanize'

$settings = {
    "user" => 'LOGINID',
    "password" => 'PASSWORD',
    "gateway_ip" => '10.0.20.1',
    "connectivity_ip" => '8.8.8.8',
    "disable_network_checks" => false,
}

begin
    require 'net/ping'
rescue LoadError
    puts "RUB: net/ping not installed, skipping network checks.."
    settings["disable_network_checks"] = true
end

# when launching over nm-dispatcher..
iface = ARGV[0]
state = ARGV[1]
def got_root?
    return Process.uid == 0
end

def check_network(ip)
    return true if $settings['disable_network_checks']
    if got_root? then
        pt = Net::Ping::ICMP.new(ip)
    else
        pt = Net::Ping::External.new(ip)
    end
    pt.timeout = 1
    res = pt.ping?
    return res
end

def do_login(username, password)
    a = Mechanize.new
    a.get('https://login.rz.ruhr-uni-bochum.de/index.html') do |page|
        login_page = page.link_with(:href => /start$/).click
        result_page = login_page.form_with(:name => 'loginbox') do |form|
            form['loginid'] = username
            form['password'] = password
            #puts "Trying to connect with user '#{username}', ip: #{form['ipaddr']}"    
            submit = form.button_with(:value => /Login/)
            result = form.submit(submit)
            success = result.body.include?('Authentisierung gelungen')
            unless success
                puts "RUB: Login failed"
                Kernel.exit
            end
        puts "RUB: Logged in succesfully"
        end
    end
end

if ARGV.length < 2 or state == "up"
    if check_network($settings['connectivity_ip']) then
        # we don't need to login, if network is already up..
        puts "RUB: Already logged in / network reachable"
        Kernel.exit
    end
    if check_network($settings['gateway_ip'])
        do_login($settings['user'], $settings['password'])
    else
        puts "RUB: Not in RUB network, #{$settings['gateway_ip']} unreachable.."
    end
end

