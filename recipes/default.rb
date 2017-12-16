#
# Cookbook:: mysqld
# Recipe:: default
#
# Copyright:: 2017, The Authors, All Rights Reserved.
#
user "mysql" do
    uid 1100
    comment "for mysql"
    shell "/bin/bash"
    password nil
    action :create
end

directory "/usr/local/lib64/mysql" do
    owner "mysql"
    group "mysql"
    mode 0755
    recursive true
    action :create
    not_if { Dir.exists?('/usr/local/lib64/mysql') }
end

port = 3307
node['mysqld_versions'].each do |version|

    match = version.match(/^\d+\.\d+/)
    execute 'wget mysql ' + version + ' tar ball' do
        command 'wget https://dev.mysql.com/get/Downloads/MySQL-' + match[0] + '/mysql-' + version + '-linux-glibc2.12-x86_64.tar.gz'
        not_if { Dir.exists?('/usr/local/lib64/mysql/' + version) }
    end

    execute 'tar zxf mysql ' + version + ' tar ball' do
        command 'tar zxf mysql-' + version + '-linux-glibc2.12-x86_64.tar.gz'
        not_if { Dir.exists?('/usr/local/lib64/mysql/' + version) }
    end

    execute 'rm mysql ' + version + ' tar ball' do
        command 'rm -f /mysql-' + version + '-linux-glibc2.12-x86_64.tar.gz'
        only_if { File.exists?('/mysql-' + version + '-linux-glibc2.12-x86_64.tar.gz') }
    end

    execute 'mv mysql ' + version + ' lib dir' do
        command 'mv mysql-' + version + '-linux-glibc2.12-x86_64 /usr/local/lib64/mysql/' + version
        not_if { Dir.exists?('/usr/local/lib64/mysql/' + version) }
    end

    %w(logs tmp data).each do |dir|
        directory '/usr/local/lib64/mysql/' + version + '/' + dir do
            owner "mysql"
            group "mysql"
            mode 0700
            recursive true
            action :create
            not_if { Dir.exists?('/usr/local/lib64/mysql/' + version + '/' + dir) }
        end
    end

    template '/usr/local/lib64/mysql/' + version + '/my.cnf' do
        owner 'mysql'
        mode 0644
        source 'my.cnf.erb'
        variables({
            :mysqld_version => version,
            :port => port
        })
    end

    execute 'chown mysql' do
        command 'chown -R mysql:mysql /usr/local/lib64/mysql/' + version
    end

    execute 'mysql  ' + version + ' initialize' do
      command '/usr/local/lib64/mysql/' + version + '/bin/mysqld --defaults-file=/usr/local/lib64/mysql/' + version + '/my.cnf --user=mysql --initialize'
        not_if { File.exists?('/usr/local/lib64/mysql/' + version + '/data/ibdata1') }
    end

    template '/etc/init.d/mysqld-' + version do
        owner 'root'
        mode 0755
        source 'init.d.mysqld.erb'
        variables({
            :mysqld_version => version
        })
    end

    execute 'mysqld chkconfig - ' + version  do
        command 'chkconfig --add mysqld-' + version
        not_if 'chkconfig --list mysqld-' + version
    end

    execute 'service mysqld start - ' + version  do
        command 'service mysqld-' + version + ' start'
        not_if { File.exists?('/usr/local/lib64/mysql/' + version + '/logs/mysqld.pid') }
    end

    port = port.next
end
