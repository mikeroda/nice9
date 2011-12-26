file "nice9.tab.rb"
file "tmo.tab.rb"

file "nice9.tab.rb" => "nice9.racc" do
    sh "racc nice9.racc"
end

file "tmo.tab.rb" => "tmo.racc" do
    sh "racc tmo.racc"
end

task :default => [:tmo, :nice9]

task :nice9 => "nice9.tab.rb"

task :tmo => "tmo.tab.rb"
