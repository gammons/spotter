#!/usr/bin/env ruby

class Terminator
  def run
    if uptime_in_seconds > 600 && number_of_users == 0
      `shutdown -h now`
    end
  end

  def number_of_users
    output = `who -q`
    output.split("\n").last.split("=").last.to_i
  end

  def uptime_in_seconds
    `cat /proc/uptime`.split(" ")[0].to_f
  end
end
Terminator.new.run
