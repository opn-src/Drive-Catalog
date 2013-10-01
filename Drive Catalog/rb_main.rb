#
#  rb_main.rb
#  Drive Catalog
#
#  Created by Pierce Corcoran on 9/21/13.
#  Copyright (c) 2013 Pierce Corcoran. All rights reserved.
#

# Loading the Cocoa framework. If you need to load more frameworks, you can
# do that here too.
framework 'Cocoa'
$:.unshift '/Users/pierce/.rvm/gems/ruby-2.0.0-p247/gems/sequel-4.2.0/lib' # sequel
$:.unshift '/Users/pierce/.rvm/gems/ruby-2.0.0-p247/gems/sqlite3-1.3.8/lib' #sqlite

require 'rubygems'
require 'sqlite3'
#require 'sequel'
require 'date'
require 'fileutils'
# Loading all the Ruby project files.
main = File.basename(__FILE__, File.extname(__FILE__))
dir_path = NSBundle.mainBundle.resourcePath.fileSystemRepresentation
Dir.glob(File.join(dir_path, '*.{rb,rbo}')).map { |x| File.basename(x, File.extname(x)) }.uniq.each do |path|
  if path != main
    require(path)
  end
end

# Starting the Cocoa main loop.
NSApplicationMain(0, nil)
