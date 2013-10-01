#
#  AppDelegate.rb
#  Drive Catalog
#
#  Created by Pierce Corcoran on 9/21/13.
#  Copyright 2013 Pierce Corcoran. All rights reserved.
#


units = {}
units['KB'] = 1024.0
units['MB'] = units['KB'] * 1024.0
units['GB'] = units['MB'] * 1024.0
units['TB'] = units['GB'] * 1024.0

Units = units

class String
  def quote
    self.gsub(/[']/, "\'\'")
  end
end

# (fold) custom NS*** classes

class NSView_indexList < NSView
  attr_accessor :delegate
  def mouseDown(event)
    super event
    delegate.rowClicked(event)
  end
end

class NSButton_fileList < NSButton
  attr_accessor :delegate
  def mouseDown(event)
    puts "mousedown"
    puts event.inspect
    delegate.mouseDown(event)
    super event
  end
end

class NSView_fileList < NSView
  # def mouseDown(event) # sender = event
  #   puts "mousedown func"
  #   super event
  # end
  def mouseDown(event)
    puts event.inspect
    super event
  end
end

class NSImageView_copypath < NSImageView
  attr_accessor :delegate
  def mouseDown(event)
    super event
    delegate.copyPathToClipboard(nil)
  end
end

class NSImageView_openinfinder < NSImageView
  attr_accessor :delegate, :searchDelegate
  def mouseDown(event)
    super event
    delegate.openInFinder(nil)
  end
end

# (end)

# (fold) helper functions
def percent(done,total)
  ((done / total.to_f) * 100).round
end

def alert(title,message)
  alert = NSAlert.alertWithMessageText( title , defaultButton:"OK",
       alternateButton:nil, otherButton:nil, informativeTextWithFormat:message)
  alert.runModal
end

def size_f(size,precision=2)
   case
     when size == 1 then "1 Byte"
     when size < Units['KB'] then "%d Bytes" % size
     when size < Units['MB'] then "%.#{precision}f KB" % (size / Units['KB'])
     when size < Units['GB'] then "%.#{precision}f MB" % (size / Units['MB'])
     when size < Units['TB'] then "%.#{precision}f GB" % (size / Units['GB'])
     else "%.#{precision}f TB" % (size / Units['TB'])
   end
end

def time_f(t)
  mm, ss = t.divmod(60)            
  hh, mm = mm.divmod(60)           
  #dd, hh = hh.divmod(24)           
  sprintf("%02d:%02d:%02ds", hh, mm, ss)
end

def pathQ(str)
  str.gsub("\"","\\\"")
end

def num_f(num)
  "#{num}".gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2')
end

def applicationSupportFolder
  paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, true)
  basePath = (paths.count > 0) ? paths[0] : NSTemporaryDirectory()
  return basePath.stringByAppendingPathComponent("Drive Catalog")
end

def gsubWildCards(item)
  item.gsub("*","%").gsub("+","_")
end

def to_size(size)
  return 0 if size == ""
  puts size.inspect
  size = size.upcase.strip
  unit = size[-2..-1]
  result = size[0..-2].to_i * Units[unit]
  puts "--#{result}--#{unit}"
  return result
end

def updateStatus(statusbar,status)
  statusbar.setStringValue status
end
# (end)
class CatalogSearchDelegate
  attr_accessor :window
  attr_accessor :pathKWs, :drives, :exts # keywords, drives, and extensions input
  attr_accessor :creation_s, :creation_e, :modification_s, :modification_e # range inputs _s to _e
  attr_accessor :creation_enable, :modification_enable # date enable
  attr_accessor :size_s, :size_e
  attr_accessor :search_button
  attr_accessor :catalog_list
  attr_accessor :files, :array_controller, :collection_view
  
  def awakeFromNib()
    puts "CatalogSearchDelegate awake"
    self.files = [
                  FileItem.new("test_path1",24536678,4523445,3545343,"drive1"),
                  FileItem.new("test_path2",102235,4523445,3545343, "drive2"),
                  FileItem.new("test_path3",102235,4523445,3545343, "drive1"),
                  FileItem.new("test_path4",102235,4523445,3545343, "drive1"),
                  FileItem.new("test_path5",102235,4523445,3545343, "drive2")
                  ]
  end
  
  def openInFinder(sender)
    puts "open /Volumes/#{array_controller.selectedObjects.first.path} in finder"
  end
  
  def copyPathToClipboard(sender)
    puts "copy /Volumes/#{array_controller.selectedObjects.first.path} in finder"
  end
  
  def creation_start_date_changed(sender)
      creation_enable.setState 1
  end
  
  def creation_end_date_changed(sender)
    creation_enable.setState 1
  end
    
  def modification_start_date_changed(sender)
    modification_enable.setState 1
  end
    
  def modification_end_date_changed(sender)
    modification_enable.setState 1
  end
end

class CatalogDriveDelegate
  attr_accessor :window
  attr_accessor :catalog_button, :drive_list, :progressbar, :notes, :statusbar, :timeleft
  
  def awakeFromNib()
    puts "CatalogDriveDelegate awake"
  end
  
  def open(sender)
    if !@cataloging
      updateStatus(statusbar,"Please Enter Drive Information")
      updateStatus(timeleft,"")
      window.makeKeyAndOrderFront nil
      tmp_drive_list = (Dir.glob('/Volumes/*').select {|f| File.directory? f}).map {|v| v[9..-1]}
      #puts window.methods(true,true)
      drive_list.removeAllItems
      drive_list.addItemsWithTitles tmp_drive_list
    else
      alert("Already Cataloging Drvie","Already Cataloging Drive: #{@cataloging_drive_name}.
Please Wait Until Cataloging Has Finished")
    end
  end
  
  def catalog_drive(sender)
    @cataloging = true
    @cataloging_drive_name = drive_list.titleOfSelectedItem
    Thread.new do
      catalog_button.enabled = false
      drive_list.enabled = false
      notes.enabled = false
      drive_window.standardWindowButton(NSWindowCloseButton).setEnabled false
      progressbar.startAnimation nil
      progressbar.setUsesThreadedAnimation true
      progressbar.setHidden false
    
      progressbar.setIndeterminate true
      
      updateStatus(statusbar,"Listing Files On Drive")
      
      dn = drive_list.titleOfSelectedItem   # get drive by inputed id 

      puts "selected #{dn}" # tell user what drive they selected
      notes = notes.stringValue # get first line of notes 

      dp = "/Volumes/#{dn}" # make a var with the path to the drive

      curloc = pathQ applicationSupportFolder # var with the absoloute path to the script
    
      puts curloc
    
      `mkdir -p "#{curloc}/"`
      `mkdir -p "#{curloc}/Listings/"`
    
      `cd "#{dp}" && find . \\( ! -regex '.*/\\..*' \\) -type f > "#{curloc}/files.tmp"` # run the command to put all the paths into a file

      progressbar.setIndeterminate false # detailed sweep (get file size/creation/modification)

      output = File.open("#{curloc}/Listings/#{dn}.dindex", 'w') # open the output file
      input = File.open("#{curloc}/files.tmp") # open the temp file with the paths listed
      linecount = `wc -l "#{curloc}/files.tmp"`
      linecount = linecount[2..-("#{curloc}/files.tmp".length)].to_i
      linenum = 0
    
      progressbar.setMaxValue linecount
    
      output.puts "#{dn}:::#{notes}" # print the header with the drive name and the notes to the output file

      updateStatus(statusbar,"Getting Detailed Data for #{num_f linecount} Files")
      updateStatus(timeleft,"Sampling Speed...")
      roundlen = 100
      updatelen = 100
      roundtime = 0
      loopstart = Time.now
      input.each_line do |line| # loop over paths in temp file
        if @terminate_catalog
          break
        end
        if linenum == roundlen
          roundtime = Time.now - loopstart
          puts roundtime
          updatelen = (linecount / 100).round
        end
        if linenum % updatelen == 0 and linenum >= roundlen
          percent = ((linenum / linecount.to_f) * 100).round
          rounds = (linecount)/roundlen
          roundsdone = (linenum)/roundlen
          roundsleft = rounds-roundsdone
          puts roundtime
          time_left = roundsleft * roundtime
          updateStatus(timeleft,"#{percent}% #{roundsleft} #{time_f time_left}")
        end
        path = line[2..-2] # clip newline and ./ off path
        abspath = pathQ "/Volumes/#{dn}/#{path}"
        size = `wc -c "#{abspath}" 2> /dev/null` # get file size
        size = size[0..-(abspath.length + 3)].strip # clip indent and filename from command output
        statout = `stat -s "#{abspath}"` # get the output of stat
        if !statout.nil?
          stats = statout.split
          modify = stats[9].split('=')[1]
          create = stats[10].split('=')[1]
        else
          modify = "0000000000"
          create = "0000000000"
        end
        output.puts "#{path}:::#{create}:::#{modify}:::#{size}" # print path and data to output file
        linenum += 1
        #updateStatus(catalog_statusbar,"Getting Detailed Data for Files (#{num_f linenum} of #{num_f linecount})")
      
        progressbar.setDoubleValue linenum
      
      end
      input.close
      output.close
      File.delete("files.tmp") if File.exist?("files.tmp")
      updateStatus(statusbar,"Detailed Data For Has Been Done")
    
      progressbar.setHidden true
      progressbar.stopAnimation nil
      catalog_button.enabled = true
      drive_list.enabled = true
      notes.enabled = true
      window.standardWindowButton(NSWindowCloseButton).setEnabled true
      window.orderOut nil
      @cataloging = false
      @terminate_catalog = false
    end
  end
  
  def terminateCatalog(sender)
    @terminate_catalog = true
  end
  
end

class CreateDBDelegate
  attr_accessor :window
  attr_accessor :indexes, :array_controller, :collection_view
  attr_accessor :database_name, :database_notes, :create_button, :progressbar, :statusbar
  
  def awakeFromNib()
    puts "CreateDBDelegate awake"
    self.indexes = [
                     DriveIndex.new(["test1"]),
                     DriveIndex.new(["test2"]),
                     DriveIndex.new(["test3"]),
                     DriveIndex.new(["test4"]),
                     DriveIndex.new(["test5"])
                     ]
  end
  
  def open(sender)
    index_loc = applicationSupportFolder + "/Listings/*.dindex"
    puts index_loc
    index_list = []
    tmp_indexes = []
    Dir.glob(index_loc).each do |item|
      first_line = File.open(item) {|f| f.readline}
      drive_notes = first_line.split(":::")[1]
      tmp_indexes.push(DriveIndex.new(item.split("/"),drive_notes))
      index_list.push item
    end
    #tmp_indexes.push(nil)
    self.indexes = tmp_indexes
    #puts index_list.map {|i| i.split("/")}.inspect
    #create_db_collection_view.reloadData
    window.makeKeyAndOrderFront nil
    puts indexes.inspect
  end
  
  def selectClicked(sender)
    #puts sender
    tmp_indexes = self.indexes
    selected = array_controller.selectedObjects
    #selected.map {|i| puts i.drive_name}
    drivename = selected.first.drive_name
    #puts drivename
    driveindex = self.indexes.find_index {|item| item.drive_name == drivename}
    tmp_indexes[driveindex].selected_flop
    #tmp_indexes[driveindex].drive_name += "s"
    self.indexes = tmp_indexes
    #puts 'clicked'
    #puts self.indexes.inspect
    #puts create_db_array_controller.arrangedObjects.first.selectChar
  end
  
  def rowClicked(event)
    selectClicked(nil)#puts event.inspect
  end
  
  def createClicked(sender)
    Thread.new do
      db_name = database_name.stringValue
      db_notes = database_notes
      drives = indexes.map {|v| v if v.selected}
      puts drives.compact.map {|v| v.drive_name}
 
    
      loop_accuracy = 0
      loop_counter = 0
      line_count = 0
      createDB(db_name,db_notes,drives.compact) { |section,data|
        case section
      
        when :main_loop
          loop_counter += 1
          if loop_counter == loop_accuracy or data[:linenum] == line_count
            updateStatus(statusbar,"On file #{num_f data[:linenum]} of #{num_f line_count}. \%#{percent(data[:linenum],line_count)}")
            progressbar.setDoubleValue data[:linenum]
            loop_counter = 0
          end
        
        when :init
          updateStatus(statusbar,"Initializing...")
          create_button.enabled = false
          database_name.enabled = false
          database_notes.enabled = false
    
          progressbar.hidden = false
          progressbar.startAnimation nil
          #progressbar.setUsesThreadedAnimation true
          progressbar.setIndeterminate true
          line_count = 0
    
          drives.compact.each do |drive|
            drive_path = "#{applicationSupportFolder}/Listings/#{drive.drive_name}.dindex"
            wcout = `wc -l '#{drive_path}'`
            drivelen = wcout[0..-(drive_path.length + 3)].strip.to_i
            line_count += drivelen
          end
          #loop_accuracy = (line_count / 50).round
          loop_accuracy = 200
          puts line_count
          progressbar.setMaxValue line_count
          progressbar.setIndeterminate false
        when :sqlite_error
        
        end
      }
    end
  end
  
  def createDB(name,notes,drives)
    yield :init, nil
    driveid = 0
    fileid = 0
    begin
      db = SQLite3::Database.new "#{applicationSupportFolder}/databases/#{name}.db"
      gline = ""
      ln = 0
      db.execute "drop table if exists Drive"
      db.execute "drop table if exists File"
      db.execute "drop table if exists GlobalData"
      db.execute "create table if not exists Drive(id INTEGER PRIMARY KEY , name VARCHAR(100), notes TEXT);"
      db.execute "create table if not exists File(id INTEGER PRIMARY KEY , drive_id INTEGER,\
       path TEXT, creation INTEGER, modification INTEGER, size INTEGER);"
      db.execute "create table if not exists GlobalData(name VARCHAR(100), notes TEXT);"
      db.execute "insert into GlobalData (name, notes) values('#{name}','#{notes}');"
      linenum = 1
      # linecount = 10000
      #linecount = linecount[2..-18].to_i
      # roundlen = 1000
      # starttimer = roundlen
      # timerbegining = Time.now
      # timeperround = 0
      drives.each do |drive|
        driveid += 1
        ln = 1
        dn = drive.drive_name
        notes = drive.drive_notes
        db.execute "insert into Drive (id,name,notes) values ('#{driveid}','#{dn.quote}','#{notes.quote}');"
        drive_linenum = 1
        File.foreach("#{applicationSupportFolder}/Listings/#{dn}.dindex") do |line|
      
          # if starttimer == 0
          #   timeperround = Time.now - timerbegining
          #   timerbegining = Time.now 
          #   starttimer = roundlen 
          # end
      
          gline = line
          if drive_linenum == 1
            
          else
            puts line
            fileid += 1
            linesplit = line.split(":::")
            path = linesplit[0]
            creation = linesplit[1]
            modification = linesplit[2]
            size = linesplit[3][0..-1]
            db.execute "insert into File (id, path, drive_id,creation,modification,size)\
             values ('#{fileid}', '#{path.quote}', '#{driveid}', '#{creation}', '#{modification}', '#{size}');"
            yield :main_loop, {:line => line,:linenum => linenum} if block_given?
          end 
          #timeleft = ((linecount-linenum)*(timeperround))/roundlen
          #timeformatted = format_time timeleft.round
          #percent_done = (linenum*100/linecount)
          #print "\r#{percent_done}% #{linenum} of #{linecount} approx #{timeformatted} left or #{timeleft} seconds                       "
          #$stdout.flush
          drive_linenum += 1
          linenum += 1
          # starttimer -= 1
        end
      end
    rescue SQLite3::Exception => e
      print "ERR:"
      puts e
      puts ln
      puts gline
      puts gline.quote
      yield :sqlite_error, {:error => e, :line => gline}
    ensure
      db.close if db
    end
  end
end

class AppDelegate
  # (fold) attr_accessors
  # => (fold) menus
  attr_accessor :catalog_drive_menu
  # => (end)
  # => (fold) main window
  attr_accessor :window
  attr_accessor :pathKWs, :drives, :exts # keywords, drives, and extensions input
  attr_accessor :creation_s, :creation_e, :modification_s, :modification_e # range inputs _s to _e
  attr_accessor :creation_enable, :modification_enable # date enable
  attr_accessor :size_s, :size_e
  attr_accessor :search_button
  attr_accessor :files, :array_controller, :collection_view
  # => (end)
  # => (fold) catalog a drive window
  attr_accessor :catalog_drive_window
  attr_accessor :catalog_button, :catalog_drive_list, :catalog_progressbar, :catalog_notes, :catalog_statusbar, :catalog_timeleft
  # => (end)
  # => (fold) create a catalog db window
  attr_accessor :create_db_window
  attr_accessor :indexes, :create_db_array_controller, :create_db_collection_view
  attr_accessor :cdb_database_name, :cdb_database_notes, :cdb_create_button, :cdb_progressbar
  # => (end)
  # (end) 
  
  def applicationDidFinishLaunching(a_notification)
    @cataloging_alert = NSAlert.alertWithMessageText("Already Cataloging Drive", defaultButton:"OK",
     alternateButton:nil, otherButton:nil, informativeTextWithFormat:"Already Cataloging Drive")
     self.files = [
                   FileItem.new("test_path1",24536678,4523445,3545343,"drive1"),
                   FileItem.new("test_path2",102235,4523445,3545343, "drive2"),
                   FileItem.new("test_path3",102235,4523445,3545343, "drive1"),
                   FileItem.new("test_path4",102235,4523445,3545343, "drive1"),
                   FileItem.new("test_path5",102235,4523445,3545343, "drive2")
                   ]
     self.indexes = [
                      DriveIndex.new(["test1"]),
                      DriveIndex.new(["test2"]),
                      DriveIndex.new(["test3"]),
                      DriveIndex.new(["test4"]),
                      DriveIndex.new(["test5"])
                      ]
  end
  
  def searchClicked(sender)
    puts "Search"
    keywords = pathKWs.objectValue.map { |v| gsubWildCards v }
    driveList   = drives.objectValue.map { |v| gsubWildCards v }
    extensions = exts.objectValue.map { |v| gsubWildCards v }
    creation = ([ creation_s.dateValue, creation_e.dateValue ] if creation_enable.state == 1) || nil
    modification = ([ modification_s.dateValue, modification_e.dateValue ] if modification_enable.state == 1) || nil
    size = [ to_size(size_s.stringValue), to_size(size_e.stringValue) ]
    puts "kw #{keywords}.dl #{driveList}.e #{extensions}.c #{creation}.m #{modification}.s #{size}"
  end
  
  # (fold) File List Actions
  def fileList_openInFinder(sender)
    puts "open #{array_controller.selectedObjects.first.path} in finder"
  end
  
  def fileList_copyPathToClipboard(sender)
    puts "copy /Volumes/#{array_controller.selectedObjects.first.path} in finder"
  end
  
  def creation_start_date_changed(sender)
      creation_enable.setState 1
  end
  
  def creation_end_date_changed(sender)
    creation_enable.setState 1
  end
    
  def modification_start_date_changed(sender)
    modification_enable.setState 1
  end
    
  def modification_end_date_changed(sender)
    modification_enable.setState 1
  end
  # (end)
  # (fold) Catalog Drive actions
  def catalog_drive_menu(sender)
    if !@cataloging
      updateStatus(catalog_statusbar,"Please Enter Drive Information")
      updateStatus(catalog_timeleft,"")
      catalog_drive_window.makeKeyAndOrderFront nil
      drive_list = (Dir.glob('/Volumes/*').select {|f| File.directory? f}).map {|v| v[9..-1]}
      puts catalog_drive_window.methods(true,true)
      catalog_drive_list.removeAllItems
      catalog_drive_list.addItemsWithTitles drive_list
    else
      @cataloging_alert.setInformativeText "Already Cataloging Drive: #{@cataloging_drive_name}.
Please Wait Until Cataloging Has Finished"
      @cataloging_alert.runModal
    end
  end
  
  def catalog_drive(sender)
    @cataloging = true
    @cataloging_drive_name = catalog_drive_list.titleOfSelectedItem
    Thread.new do
      catalog_button.enabled = false
      catalog_drive_list.enabled = false
      catalog_notes.enabled = false
      catalog_drive_window.standardWindowButton(NSWindowCloseButton).setEnabled false
      catalog_progressbar.startAnimation nil
    
      catalog_progressbar.setHidden false
    
      catalog_progressbar.setIndeterminate true
      
      updateStatus(catalog_statusbar,"Listing Files On Drive")
      
      dn = catalog_drive_list.titleOfSelectedItem   # get drive by inputed id 

      puts "selected #{dn}" # tell user what drive they selected
      notes = catalog_notes.stringValue # get first line of notes 

      dp = "/Volumes/#{dn}" # make a var with the path to the drive

      curloc = pathQ applicationSupportFolder # var with the absoloute path to the script
    
      puts curloc
    
      `mkdir -p "#{curloc}/"`
      `mkdir -p "#{curloc}/Listings/"`
    
      `cd "#{dp}" && find . \\( ! -regex '.*/\\..*' \\) -type f > "#{curloc}/files.tmp"` # run the command to put all the paths into a file

      catalog_progressbar.setIndeterminate false # detailed sweep (get file size/creation/modification)

      output = File.open("#{curloc}/Listings/#{dn}.dindex", 'w') # open the output file
      input = File.open("#{curloc}/files.tmp") # open the temp file with the paths listed
      linecount = `wc -l "#{curloc}/files.tmp"`
      linecount = linecount[2..-("#{curloc}/files.tmp".length)].to_i
      linenum = 0
    
      catalog_progressbar.setMaxValue linecount
    
      output.puts "#{dn}:::#{notes}" # print the header with the drive name and the notes to the output file

      updateStatus(catalog_statusbar,"Getting Detailed Data for #{num_f linecount} Files")
      updateStatus(catalog_timeleft,"Sampling Speed...")
      roundlen = 100
      updatelen = 100
      roundtime = 0
      loopstart = Time.now
      input.each_line do |line| # loop over paths in temp file
        if @terminate_catalog
          break
        end
        if linenum == roundlen
          roundtime = Time.now - loopstart
          puts roundtime
          updatelen = (linecount / 100).round
        end
        if linenum % updatelen == 0 and linenum >= roundlen
          percent = ((linenum / linecount.to_f) * 100).round
          rounds = (linecount)/roundlen
          roundsdone = (linenum)/roundlen
          roundsleft = rounds-roundsdone
          puts roundtime
          time_left = roundsleft * roundtime
          updateStatus(catalog_timeleft,"#{percent}% #{roundsleft} #{time_f time_left}")
        end
        path = line[2..-2] # clip newline and ./ off path
        abspath = pathQ "/Volumes/#{dn}/#{path}"
        size = `wc -c "#{abspath}" 2> /dev/null` # get file size
        size = size[0..-(abspath.length + 3)].strip # clip indent and filename from command output
        statout = `stat -s "#{abspath}"` # get the output of stat
        if !statout.nil?
          stats = statout.split
          modify = stats[9].split('=')[1]
          create = stats[10].split('=')[1]
        else
          modify = "0000000000"
          create = "0000000000"
        end
        output.puts "#{path}:::#{create}:::#{modify}:::#{size}" # print path and data to output file
        linenum += 1
        #updateStatus(catalog_statusbar,"Getting Detailed Data for Files (#{num_f linenum} of #{num_f linecount})")
      
        catalog_progressbar.setDoubleValue linenum
      
      end
      input.close
      output.close
      File.delete("files.tmp") if File.exist?("files.tmp")
      updateStatus(catalog_statusbar,"Detailed Data For Has Been Done")
    
      catalog_progressbar.setHidden true
      catalog_progressbar.stopAnimation nil
      catalog_button.enabled = true
      catalog_drive_list.enabled = true
      catalog_notes.enabled = true
      catalog_drive_window.standardWindowButton(NSWindowCloseButton).setEnabled true
      catalog_drive_window.orderOut nil
      @cataloging = false
      @terminate_catalog = false
    end
  end
  
  def terminateCatalog(sender)
    @terminate_catalog = true
  end
  # (end)
  # (fold) Create DB actions
  def createDB_menu(sender)
    index_loc = applicationSupportFolder + "/Listings/*.dindex"
    puts index_loc
    index_list = []
    tmp_indexes = []
    Dir.glob(index_loc).each do |item|
      tmp_indexes.push(DriveIndex.new(item.split("/")))
      index_list.push item
    end
    #tmp_indexes.push(nil)
    self.indexes = tmp_indexes
    #puts index_list.map {|i| i.split("/")}.inspect
    #create_db_collection_view.reloadData
    create_db_window.makeKeyAndOrderFront nil
    puts indexes.inspect
  end
  
  def createDB_selectClicked(sender)
    #puts sender
    tmp_indexes = self.indexes
    selected = create_db_array_controller.selectedObjects
    #selected.map {|i| puts i.drive_name}
    drivename = selected.first.drive_name
    #puts drivename
    driveindex = self.indexes.find_index {|item| item.drive_name == drivename}
    tmp_indexes[driveindex].selected_flop
    #tmp_indexes[driveindex].drive_name += "s"
    self.indexes = tmp_indexes
    #puts 'clicked'
    #puts self.indexes.inspect
    #puts create_db_array_controller.arrangedObjects.first.selectChar
  end
  
  def createDB_rowClicked(event)
    createDB_selectClicked(nil)#puts event.inspect
  end
  
  def createDB_createClicked(sender)
    db_name = cdb_database_name.stringValue
    db_notes = cdb_dateabase_notes 
  end
  # (end)
end
# (fold) model classes
class FileItem
  attr_accessor :path, :size, :modification, :creation, :drive
  
  def initialize(pth,sze,mod,cre,drive)
    @dateFormat = "%b %d, %Y"
    self.drive = drive
    self.path = pth
    self.size = sze
    self.modification = Time.at(mod).to_datetime
    self.creation = Time.at(cre).to_datetime
  end
  
  def size
    size_f(@size)
  end
  
  def modification
    @modification.strftime(@dateFormat)
  end
  
  def creation
    @creation.strftime(@dateFormat)
  end
end

class DriveIndex
  attr_accessor :drive_name, :selected, :selectChar, :drive_notes #, :drive_path
  def initialize(drivePath, driveNotes="")
   # self.drive_path = drivePath
    self.drive_name = drivePath.last[0..-8]
    self.selected = false
    self.drive_notes = driveNotes
  end
  
  def selected=(sel)
    @selected = sel
    if self.selected
      self.selectChar = '✓'
    else
      self.selectChar = '✗'
    end
  end
  def selected_flop
    self.selected = !self.selected
  end

end

# (end)