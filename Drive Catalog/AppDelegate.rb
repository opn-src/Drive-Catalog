#
#  AppDelegate.rb
#  Drive Catalog
#
#  Created by Pierce Corcoran on 9/21/13.
#  Copyright 2013 Pierce Corcoran. All rights reserved.
#

#(fold) class extensions
class String
  def quote
    self.gsub(/[']/, "\'\'")
  end
  
  def sqlescape
    self.gsub(/\\/, '\&\&').gsub(/'/, "''")
  end
end

class Time 
  def nsdate
    return NSDate.dateWithString(self.to_s)
  end
end

# class SQLite3::Database
#   def exec_hash(sql,*bind_vars)
#     columns = []
#     rows = []
#     first_row = true
#     self.execute2(sql,*bind_vars) do |row|
#       if first_row
#         columns = row.map {|c| c.to_sym}
#         first_row = false
#       else
#         row_hash = {}
#         row.each_index do |index|
#           row_hash[columns[index]] = row[index]
#         end
#       end
#     end
#     
#     return rows
#   end
# end
#(end)

#(fold) constants
units = {}
units['KB'] = 1024.0
units['MB'] = units['KB'] * 1024.0
units['GB'] = units['MB'] * 1024.0
units['TB'] = units['GB'] * 1024.0

Units = units

ZeroDate = Time.local(1984,1,1).nsdate
#(end)

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

class NSTextField_multiline < NSTextField
  def textShouldEndEditing(textObject)
    event = NSApplication.sharedApplication.currentEvent
    if event.type == NSKeyDown && event.keyCode == 36
      self.setStringValue(self.stringValue + "\n")
      return false
    else
      return super textObject
    end
  end
end

# (end)

# (fold) helper functions
def percent(done,total)
  ((done / total.to_f) * 100).round
end

def confirm(msg="Are you sure?", title="", alert_style=nil)
  alert = NSAlert.alertWithMessageText(title,
                                       defaultButton:"No",
                                       alternateButton:"Yes",
                                       otherButton:nil,
                                       informativeTextWithFormat:msg)
  alert.alertStyle = alert_style if alert_style
  alert.runModal == 0 ? true : false
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

def wildcards(item,gsubs=[['*','%'],['+','_']])
  result = item.dup
  gsubs.each do |i|
    matchQuote = Regexp.quote(i[0])
    areg = /(?<!\\)#{matchQuote}/
    breg = /\\#{matchQuote}/
    result = result.gsub(areg,i[1])
    result = result.gsub(breg,i[0])
  end
  return result.sqlescape
end

def constructSQL(table,conds,seperator="AND")
  if conds.empty?
    sql = "SELECT * FROM #{table.sqlescape}"
  else
    sql = "SELECT * FROM #{table.sqlescape} WHERE #{conds.join(" " + seperator + " ")}"
  end
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

# (fold) helper classes  
class FileSearch
  attr_accessor :keywords, :drives, :extensions, :creation, :modifcation, :size# , :sql, :drivesql
  def initialize(db,_keywords=[], _drives=[], _extensions=[], _creation=[], _modification=[], _size=[])
    @db = db
    @keywords = _keywords || []
    @drives = _drives || []
    @extensions = _extensions || []
    @creation = _creation || []
    @modification = _modification || []
    @size = _size || []
    @drivesql = ''
    @sql = ''
  end
  
  def compileSQL()
    puts "k #{@keywords.inspect}"
    puts "d #{@drives.inspect}"
    puts "e #{@extensions.inspect}"
    puts "c #{@creation.inspect}"
    puts "m #{@modification.inspect}"
    puts "s #{@size.inspect}"
    
    conds = []
    driveconds = []
    if !@keywords.empty?
      @keywords.each do |key|
        conds << "path LIKE '%#{key}%'"
      end
    end
    if !@drives.empty?
      puts "doing drives"
      @drives.each do |drive|
        driveconds << "name LIKE '#{drive}'"
        puts driveconds
      end
    end
    if !@extensions.empty?
      @extensions.each do |ext|
        if ext[0] == '.'
          ext = ext[1..-1]
        end
        conds << "path LIKE '%.#{ext}'"
      end
    end
    if !@creation.empty?
      conds << "creation < #{@creation[0].timeIntervalSince1970} AND creation > #{@creation[1].timeIntervalSince1970}"
    end
    if !@modification.empty?
      conds << "modification > #{@modification[0].timeIntervalSince1970} AND modification < #{@modification[1].timeIntervalSince1970}"
    end
    if !@size.empty?
      conds << "size > #{@size[0]} AND #{@size[1]} < end"
    end
    
    conds << '1=1'
    @drivesql = constructSQL('Drive',driveconds)
    @sql = constructSQL('File',conds)
    puts "--DriveSQL-- #{@drivesql} --DriveSQL--"
    puts " --MainSQL-- #{@sql} --MainSQL--"
  end
  
  def doSQL()
    firstrow = true
    rows = []
    driverows = []
    begin
      columns = []
      # (fold) get drive rows
      @db.execute2(@drivesql) do |row|
        if firstrow
          columns = row.map {|c| c.to_sym}
          firstrow = false
          next
        end
        row_hash = {}
        row.each_index do |index|
          puts "in row loop"
          row_hash[columns[index]] = row[index]
        end
        driverows << row_hash
      end
      # (end)
      #puts driverows
      ids = driverows.map {|r| r[:id]}
      fullsql = ""
      if ids.empty?
        fullsql = "#{@sql}"
      elsif ids.length == 1
        fullsql = "#{@sql} AND drive_id=#{ids[0]}"
      else
        fullsql = "#{@sql} AND drive_id IN (#{ids.join(',')})"
      end
      puts fullsql
      firstrow = true
      columns = []
      
      @db.execute2(fullsql) do |row|
        if firstrow
          columns = row.map {|c| c.to_sym}
          firstrow = false
          next
        end
        row_hash = {}
        row.each_index do |index|
          #puts "in row loop 2"
          row_hash[columns[index]] = row[index]
        end
        rows << row_hash
      end
      #puts rows
    rescue SQLite3::SQLException => e
      puts e.backtrace
      alert("ERROR:","ERROR:\nSQLite3::SQLException => #{e}\nThis usually means that the database was not built properly")
    end
    return {:drives => driverows, :files => rows}
  end
end
# (end)

class CatalogSearchDelegate
  attr_accessor :window
  attr_accessor :pathKWs_input, :drives_input, :exts_input # keywords, drives, and extensions input
  attr_accessor :creation_s, :creation_e, :modification_s, :modification_e # range inputs _s to _e
  attr_accessor :creation_enable, :modification_enable # date enable
  attr_accessor :size_s, :size_e
  attr_accessor :search_button
  attr_accessor :catalog_list
  attr_accessor :progresswheel
  attr_accessor :files, :array_controller, :collection_view
  
  attr_accessor :fileNum
  
  def awakeFromNib()
    puts "CatalogSearchDelegate awake"
    self.files = [
                  FileItem.new("test_path1",24536678,4523445,3545343,"drive1"),
                  FileItem.new("test_path2",102235,4523445,3545343, "drive2"),
                  FileItem.new("test_path3",102235,4523445,3545343, "drive1"),
                  FileItem.new("test_path4",102235,4523445,3545343, "drive1"),
                  FileItem.new("test_path5",102235,4523445,3545343, "drive2")
                  ]
    self.refreshCatalogList(nil)
    self.refreshDriveList(nil)
    creation_e.setDateValue Time.now.nsdate
    modification_e.setDateValue Time.now.nsdate
    puts ZeroDate.inspect
    creation_s.setDateValue ZeroDate
    modification_s.setDateValue ZeroDate
  end
  
  def cleanUp(sender)
    @db.close if @db
    puts 'cleaning up'
  end
  
  def openInFinder(sender)
    sel = array_controller.selectedObjects.first
    puts "#{sel.drive}:#{sel.path}"
    applescript = %Q|
tell application "Finder"
 reveal "#{sel.drive}:#{sel.path}"
end tell|
    puts applescript
  end
  
  def copyPathToClipboard(sender)
    puts "copy /Volumes/#{array_controller.selectedObjects.first.path} in finder"
  end
  
  # (fold) date inputs changed
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
  
  # (fold) creation date jumps
  def creation_start_to_now(sender)
    creation_s.setDateValue Time.now.nsdate
    creation_enable.setState 1
  end
  
  def creation_start_to_zero(sender)
    creation_s.setDateValue ZeroDate
    creation_enable.setState 1
  end
  
  def creation_end_to_now(sender)
    creation_e.setDateValue Time.now.nsdate
    creation_enable.setState 1
  end
  
  def creation_end_to_zero(sender)
    creation_e.setDateValue ZeroDate
    creation_enable.setState 1
  end
  # (end)
  
  # (fold) modification date jumps
  def modification_start_to_now(sender)
    modification_s.setDateValue Time.now.nsdate
    modification_enable.setState 1
  end
  
  def modification_start_to_zero(sender)
    modification_s.setDateValue ZeroDate
    modification_enable.setState 1
  end
  
  def modification_end_to_now(sender)
    modification_e.setDateValue Time.now.nsdate
    modification_enable.setState 1
  end
  
  def modification_end_to_zero(sender)
    modification_e.setDateValue ZeroDate
    modification_enable.setState 1    
  end
  # (end)
  
  def refreshCatalogList(sender)
    catalogs_dirlist = Dir["#{applicationSupportFolder}/databases/*.db"].select {|f| !File.directory? f}
    catalogs_names = catalogs_dirlist.map {|f| File.basename(f,".db")}.unshift('---')
    puts catalogs_names
    catalog_list.removeAllItems
    catalog_list.addItemsWithTitles catalogs_names
    @selected = catalog_list.titleOfSelectedItem
    @db = nil
  end
  
  def refreshDriveList(sender)
    if @db
      @drives = @db.execute("SELECT * FROM Drive")
      puts @drives
    end
    puts "__#{@drives}"
  end
  
  def catalogListChanged(sender)
    oldSelected = @selected
    @selected = catalog_list.titleOfSelectedItem
    if @selected == '---'
      @selected = oldSelected
      catalog_list.selectItemWithTitle @selected
    else
      if confirm("Are you sure you want to switch to the '#{@selected}' catalog?","",1)
        @db = SQLite3::Database.open "#{applicationSupportFolder}/databases/#{@selected}.db"
        puts @db.inspect
        refreshDriveList(nil)
      else
        @selected = oldSelected
        catalog_list.selectItemWithTitle @selected
      end
    end
  end
  
  def nextPage(sender)
    puts @pagenum
    if !(@pagenum+1 >= @allfiles.length)
      @pagenum += 1
      self.files = @allfiles[@pagenum]
    end 
    puts @pagenum
  end 
  
  def prevPage(sender)
    puts @pagenum
    if @pagenum-1 >= 0
      @pagenum -= 1
      self.files = @allfiles[@pagenum]
    end
    puts @pagenum
  end
  
  def search(sender)
    if @db.nil?
      alert("Select A Catalog","Select a Catalog to search")
      return
    end
    puts creation_enable.state
    unsub_keywords = pathKWs_input.objectValue
    unsub_drives   = drives_input.objectValue
    unsub_exts     = exts_input.objectValue
    
    keywords = (unsub_keywords.map {|v| wildcards(v)} if unsub_keywords) || []
    drives   = (unsub_drives.map {|v| wildcards(v)} if unsub_drives) || []
    exts     = (unsub_exts.map {|v| wildcards(v)} if unsub_exts) || []
    
    creation = creation_enable.state == 1 ? [creation_s.dateValue, creation_e.dateValue] : []
    if creation != [] and creation[0].compare(creation[1]) == NSOrderedDescending
      creation = creation.reverse
    end
    modification = modification_enable.state == 1 ? [modification_s.dateValue, modification_e.dateValue] : []
    if modification != [] and modification[0].compare(modification[1]) == NSOrderedDescending
      modification = modification.reverse
    end
    # (fold) Get size
    sizeRegex = /\s{0,}\d+.?(KB|MB|GB|TB)\s{0,}/i
    size_s_match = !(size_s.stringValue =~ sizeRegex).nil?
    size_e_match = !(size_e.stringValue =~ sizeRegex).nil?
    
    if size_s_match and size_e_match
      size = [to_size(size_s.stringValue.strip), to_size(size_e.stringValue.strip)]
      
      if size[0] > size[1]
        size.reverse!
      end
    else
      size = []
    end

    # (end)
    searcher = FileSearch.new(@db,keywords,drives,exts,creation,modification,size)
    searcher.compileSQL()
    progresswheel.startAnimation nil
    result = searcher.doSQL()
    tmpfiles = []
    result[:files].each do |file|
      tmpfile = FileItem.new(file[:path],file[:size],file[:modification],file[:creation],"drive")
      tmpfiles << tmpfile
    end
    @filecount = tmpfiles.length
    @allfiles = tmpfiles.each_slice(50).to_a
    @pagenum = 0
    self.files = @allfiles[0]
    self.fileNum = num_f @filecount
    progresswheel.stopAnimation nil
  end

  def tokenField (tokenField, completionsForSubstring: substring, indexOfToken: tokenIndex, indexOfSelectedItem: selectedIndex)
    complete = []
    if @drives 
      completeObjs = @drives.select { |drive| drive[1].upcase.start_with?(substring.upcase) }
      complete = completeObjs.map { |drive| drive[1]}
    end
    return complete
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
    @thread = Thread.new do
      @thread[:can_quit] = false
      catalog_button.enabled = false
      drive_list.enabled = false
      notes.enabled = false
      window.standardWindowButton(NSWindowCloseButton).setEnabled false
      progressbar.startAnimation nil
      progressbar.setUsesThreadedAnimation true
      progressbar.setHidden false
    
      progressbar.setIndeterminate true
      
      updateStatus(statusbar,"Getting list of files on drive (may take a long time)")
      
      dn = drive_list.titleOfSelectedItem   # get drive by inputed id 

      puts "selected #{dn}" # tell user what drive they selected
      notes = notes.stringValue # get first line of notes 

      dp = "/Volumes/#{dn}" # make a var with the path to the drive

      curloc = pathQ applicationSupportFolder # var with the absoloute path to the script
    
      puts curloc
    
      `mkdir -p "#{curloc}/"`
      `mkdir -p "#{curloc}/Listings/"`
    
      `cd "#{dp}" && find . \\( ! -regex '.*/\\..*' \\) -type f > "#{curloc}/files.tmp"` # run the command to put all the paths into a file
      @thread[:can_quit] = true
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
    
      thread_exit()
    end
  end
  
  def thread_exit
    progressbar.setHidden true
    progressbar.stopAnimation nil
    catalog_button.enabled = true
    drive_list.enabled = true
    notes.enabled = true
    window.standardWindowButton(NSWindowCloseButton).setEnabled true
    window.orderOut nil
    puts "ordering out window"
    @cataloging = false
    @terminate_catalog = false
  end
  
  def terminateCatalog(sender)
    if !@thread[:can_quit]
      @thread.kill
      puts "killed thread"
      thread_exit()
    end
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
    database_notes.enabled = true
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
        
        when :end
          create_button.enabled  = true
          database_name.enabled  = true
          database_notes.enabled = true
    
          progressbar.hidden = true
          progressbar.stopAnimation nil
          window.orderOut nil
          
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
    yield :end, nil
  end
end

class AppDelegate
  # quit items
  attr_accessor :quit1, :quit2, :quit3
  # application
  attr_accessor :application
  def terminate(sender)
    
    #call cleanUp(nil) on each quit item
    quit1.cleanUp(nil) if quit1
    quit2.cleanUp(nil) if quit2
    quit3.cleanup(nil) if quit3
    application.terminate(sender)
  end
end
# (fold) old appdelegate
# class AppDelegate
#   # (fold) attr_accessors
#   # => (fold) menus
#   attr_accessor :catalog_drive_menu
#   # => (end)
#   # => (fold) main window
#   attr_accessor :window
#   attr_accessor :pathKWs, :drives, :exts # keywords, drives, and extensions input
#   attr_accessor :creation_s, :creation_e, :modification_s, :modification_e # range inputs _s to _e
#   attr_accessor :creation_enable, :modification_enable # date enable
#   attr_accessor :size_s, :size_e
#   attr_accessor :search_button
#   attr_accessor :files, :array_controller, :collection_view
#   # => (end)
#   # => (fold) catalog a drive window
#   attr_accessor :catalog_drive_window
#   attr_accessor :catalog_button, :catalog_drive_list, :catalog_progressbar, :catalog_notes, :catalog_statusbar, :catalog_timeleft
#   # => (end)
#   # => (fold) create a catalog db window
#   attr_accessor :create_db_window
#   attr_accessor :indexes, :create_db_array_controller, :create_db_collection_view
#   attr_accessor :cdb_database_name, :cdb_database_notes, :cdb_create_button, :cdb_progressbar
#   # => (end)
#   # (end) 
#   
#   def applicationDidFinishLaunching(a_notification)
#     @cataloging_alert = NSAlert.alertWithMessageText("Already Cataloging Drive", defaultButton:"OK",
#      alternateButton:nil, otherButton:nil, informativeTextWithFormat:"Already Cataloging Drive")
#      self.files = [
#                    FileItem.new("test_path1",24536678,4523445,3545343,"drive1"),
#                    FileItem.new("test_path2",102235,4523445,3545343, "drive2"),
#                    FileItem.new("test_path3",102235,4523445,3545343, "drive1"),
#                    FileItem.new("test_path4",102235,4523445,3545343, "drive1"),
#                    FileItem.new("test_path5",102235,4523445,3545343, "drive2")
#                    ]
#      self.indexes = [
#                       DriveIndex.new(["test1"]),
#                       DriveIndex.new(["test2"]),
#                       DriveIndex.new(["test3"]),
#                       DriveIndex.new(["test4"]),
#                       DriveIndex.new(["test5"])
#                       ]
#   end
#   
#   def searchClicked(sender)
#     puts "Search"
#     keywords = pathKWs.objectValue.map { |v| gsubWildCards v }
#     driveList   = drives.objectValue.map { |v| gsubWildCards v }
#     extensions = exts.objectValue.map { |v| gsubWildCards v }
#     creation = ([ creation_s.dateValue, creation_e.dateValue ] if creation_enable.state == 1) || nil
#     modification = ([ modification_s.dateValue, modification_e.dateValue ] if modification_enable.state == 1) || nil
#     size = [ to_size(size_s.stringValue), to_size(size_e.stringValue) ]
#     puts "kw #{keywords}.dl #{driveList}.e #{extensions}.c #{creation}.m #{modification}.s #{size}"
#   end
#   
#   # (fold) File List Actions
#   def fileList_openInFinder(sender)
#     puts "open #{array_controller.selectedObjects.first.path} in finder"
#   end
#   
#   def fileList_copyPathToClipboard(sender)
#     puts "copy /Volumes/#{array_controller.selectedObjects.first.path} in finder"
#   end
#   
#   def creation_start_date_changed(sender)
#       creation_enable.setState 1
#   end
#   
#   def creation_end_date_changed(sender)
#     creation_enable.setState 1
#   end
#     
#   def modification_start_date_changed(sender)
#     modification_enable.setState 1
#   end
#     
#   def modification_end_date_changed(sender)
#     modification_enable.setState 1
#   end
#   # (end)
#   # (fold) Catalog Drive actions
#   def catalog_drive_menu(sender)
#     if !@cataloging
#       updateStatus(catalog_statusbar,"Please Enter Drive Information")
#       updateStatus(catalog_timeleft,"")
#       catalog_drive_window.makeKeyAndOrderFront nil
#       drive_list = (Dir.glob('/Volumes/*').select {|f| File.directory? f}).map {|v| v[9..-1]}
#       puts catalog_drive_window.methods(true,true)
#       catalog_drive_list.removeAllItems
#       catalog_drive_list.addItemsWithTitles drive_list
#     else
#       @cataloging_alert.setInformativeText "Already Cataloging Drive: #{@cataloging_drive_name}.
# Please Wait Until Cataloging Has Finished"
#       @cataloging_alert.runModal
#     end
#   end
#   
#   def catalog_drive(sender)
#     @cataloging = true
#     @cataloging_drive_name = catalog_drive_list.titleOfSelectedItem
#     Thread.new do
#       catalog_button.enabled = false
#       catalog_drive_list.enabled = false
#       catalog_notes.enabled = false
#       catalog_drive_window.standardWindowButton(NSWindowCloseButton).setEnabled false
#       catalog_progressbar.startAnimation nil
#     
#       catalog_progressbar.setHidden false
#     
#       catalog_progressbar.setIndeterminate true
#       
#       updateStatus(catalog_statusbar,"Listing Files On Drive")
#       
#       dn = catalog_drive_list.titleOfSelectedItem   # get drive by inputed id 
# 
#       puts "selected #{dn}" # tell user what drive they selected
#       notes = catalog_notes.stringValue # get first line of notes 
# 
#       dp = "/Volumes/#{dn}" # make a var with the path to the drive
# 
#       curloc = pathQ applicationSupportFolder # var with the absoloute path to the script
#     
#       puts curloc
#     
#       `mkdir -p "#{curloc}/"`
#       `mkdir -p "#{curloc}/Listings/"`
#     
#       `cd "#{dp}" && find . \\( ! -regex '.*/\\..*' \\) -type f > "#{curloc}/files.tmp"` # run the command to put all the paths into a file
# 
#       catalog_progressbar.setIndeterminate false # detailed sweep (get file size/creation/modification)
# 
#       output = File.open("#{curloc}/Listings/#{dn}.dindex", 'w') # open the output file
#       input = File.open("#{curloc}/files.tmp") # open the temp file with the paths listed
#       linecount = `wc -l "#{curloc}/files.tmp"`
#       linecount = linecount[2..-("#{curloc}/files.tmp".length)].to_i
#       linenum = 0
#     
#       catalog_progressbar.setMaxValue linecount
#     
#       output.puts "#{dn}:::#{notes}" # print the header with the drive name and the notes to the output file
# 
#       updateStatus(catalog_statusbar,"Getting Detailed Data for #{num_f linecount} Files")
#       updateStatus(catalog_timeleft,"Sampling Speed...")
#       roundlen = 100
#       updatelen = 100
#       roundtime = 0
#       loopstart = Time.now
#       input.each_line do |line| # loop over paths in temp file
#         if @terminate_catalog
#           break
#         end
#         if linenum == roundlen
#           roundtime = Time.now - loopstart
#           puts roundtime
#           updatelen = (linecount / 100).round
#         end
#         if linenum % updatelen == 0 and linenum >= roundlen
#           percent = ((linenum / linecount.to_f) * 100).round
#           rounds = (linecount)/roundlen
#           roundsdone = (linenum)/roundlen
#           roundsleft = rounds-roundsdone
#           puts roundtime
#           time_left = roundsleft * roundtime
#           updateStatus(catalog_timeleft,"#{percent}% #{roundsleft} #{time_f time_left}")
#         end
#         path = line[2..-2] # clip newline and ./ off path
#         abspath = pathQ "/Volumes/#{dn}/#{path}"
#         size = `wc -c "#{abspath}" 2> /dev/null` # get file size
#         size = size[0..-(abspath.length + 3)].strip # clip indent and filename from command output
#         statout = `stat -s "#{abspath}"` # get the output of stat
#         if !statout.nil?
#           stats = statout.split
#           modify = stats[9].split('=')[1]
#           create = stats[10].split('=')[1]
#         else
#           modify = "0000000000"
#           create = "0000000000"
#         end
#         output.puts "#{path}:::#{create}:::#{modify}:::#{size}" # print path and data to output file
#         linenum += 1
#         #updateStatus(catalog_statusbar,"Getting Detailed Data for Files (#{num_f linenum} of #{num_f linecount})")
#       
#         catalog_progressbar.setDoubleValue linenum
#       
#       end
#       input.close
#       output.close
#       File.delete("files.tmp") if File.exist?("files.tmp")
#       updateStatus(catalog_statusbar,"Detailed Data For Has Been Done")
#     
#       catalog_progressbar.setHidden true
#       catalog_progressbar.stopAnimation nil
#       catalog_button.enabled = true
#       catalog_drive_list.enabled = true
#       catalog_notes.enabled = true
#       catalog_drive_window.standardWindowButton(NSWindowCloseButton).setEnabled true
#       catalog_drive_window.orderOut nil
#       @cataloging = false
#       @terminate_catalog = false
#     end
#   end
#   
#   def terminateCatalog(sender)
#     @terminate_catalog = true
#   end
#   # (end)
#   # (fold) Create DB actions
#   def createDB_menu(sender)
#     index_loc = applicationSupportFolder + "/Listings/*.dindex"
#     puts index_loc
#     index_list = []
#     tmp_indexes = []
#     Dir.glob(index_loc).each do |item|
#       tmp_indexes.push(DriveIndex.new(item.split("/")))
#       index_list.push item
#     end
#     #tmp_indexes.push(nil)
#     self.indexes = tmp_indexes
#     #puts index_list.map {|i| i.split("/")}.inspect
#     #create_db_collection_view.reloadData
#     create_db_window.makeKeyAndOrderFront nil
#     puts indexes.inspect
#   end
#   
#   def createDB_selectClicked(sender)
#     #puts sender
#     tmp_indexes = self.indexes
#     selected = create_db_array_controller.selectedObjects
#     #selected.map {|i| puts i.drive_name}
#     drivename = selected.first.drive_name
#     #puts drivename
#     driveindex = self.indexes.find_index {|item| item.drive_name == drivename}
#     tmp_indexes[driveindex].selected_flop
#     #tmp_indexes[driveindex].drive_name += "s"
#     self.indexes = tmp_indexes
#     #puts 'clicked'
#     #puts self.indexes.inspect
#     #puts create_db_array_controller.arrangedObjects.first.selectChar
#   end
#   
#   def createDB_rowClicked(event)
#     createDB_selectClicked(nil)#puts event.inspect
#   end
#   
#   def createDB_createClicked(sender)
#     db_name = cdb_database_name.stringValue
#     db_notes = cdb_dateabase_notes 
#   end
#   # (end)
# end
# (end)

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
  
  def filename
    @path #File.basename(@path)
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