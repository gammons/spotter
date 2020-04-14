require_relative "spotter"

desc "Launch spot instance"
task :launch_spot_instance do
  Spotter.new.get_spot_instance
end

# task :attach_volumes do
#   Spotter.new.attach_volumes("vol-04aad1559ad325118","i-05bdbb8cbb0559741")
# end

task default: :launch_spot_instance
