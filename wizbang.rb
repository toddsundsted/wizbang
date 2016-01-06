#!/usr/bin/env ruby

unless system('docker -v > /dev/null 2>&1')
  abort 'Docker does not appear to be installed'
end

unless File.exists?('.git')
  abort 'This does not appear to be a git repository'
end

unless File.exists?('config.ru')
  abort 'This does not appear to be a Rack project'
end

dockerfile = <<-EOF.gsub(/^ */, '')
  FROM ubuntu:14.04
  RUN apt-get update && apt-get install --no-install-recommends -y -q curl build-essential autoconf libssl-dev libyaml-dev libxml2-dev libxslt1-dev zlib1g-dev libgdbm-dev libsqlite3-dev sqlite3
EOF

unless system('docker inspect wizbang-builder > /dev/null 2>&1')
  puts 'WIZBANG: Creating image for building rubies: wizbang-builder'
  system("echo \"#{dockerfile}\" | docker build --tag wizbang-builder -")
end

unless system('docker inspect wizbang-rubies > /dev/null 2>&1')
  puts 'WIZBANG: Creating shared volume for built rubies: wizbang-rubies'
  system("docker run -v /wizbang/rubies --name wizbang-rubies busybox true")
end


built_rubies = `docker run --rm --volumes-from wizbang-rubies busybox ls /wizbang/rubies`.split

ruby_version = File.exists?('.ruby-version') ? IO.readlines('.ruby-version').first.strip : '2.1.5'

if !built_rubies.include?(ruby_version)
  system("docker run --rm --volumes-from wizbang-rubies wizbang-builder /bin/bash -c 'mkdir -p /wizbang/rubies/#{ruby_version} && mkdir -p /usr/src && curl -s http://ftp.ruby-lang.org/pub/ruby/ruby-#{ruby_version}.tar.bz2 | tar -C /usr/src -xj && cd /usr/src/ruby-#{ruby_version} && autoconf && ./configure --prefix=/wizbang/rubies/#{ruby_version} --disable-install-doc && make && make install'")
end


File.open('Dockerfile', 'w') do |f|
  f.puts <<-EOF.gsub(/^ */, '')
    FROM ubuntu:14.04
    RUN apt-get update && apt-get install --no-install-recommends -y -q git && mkdir -p /app/.git
    ADD .git/ /app/.git/
    WORKDIR /app/
    RUN git checkout .
    RUN ls -al
  EOF
end

system('docker build --rm .')
