#!/usr/bin/env ruby
require 'rubygems'
require 'mechanize'
require 'net/ping'

settings = {"user" => 'LOGINID',
         "password" => 'PASSWORD',
         "ping_ip" => '10.0.20.1'
}

iface = ARGV[0]
state = ARGV[1]

def got_root?
    return Process.uid == 0
end

def check_network(ip)
    pt = Net::Ping::ICMP.new(ip)
    return pt.ping?
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
    if got_root? and check_network('8.8.8.8') then
        # we don't need to login, if network is already up..
        puts "RUB: Already logged in / network reachable"
        Kernel.exit
    end
    if not got_root? or check_network(settings['ping_ip'])
        do_login(settings['user'], settings['password'])
    else
        puts "RUB: Not in RUB network, #{settings['ping_ip']} unreachable.."
    end
end

