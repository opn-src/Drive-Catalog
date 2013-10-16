#
#  AppDelegate.rb
#  Drive Catalog
#
#  Created by Pierce Corcoran on 9/21/13.
#  Copyright 2013 Pierce Corcoran. All rights reserved.
#

def compare_file_letters(file,letters)
  path = file.path
  pathArr = path.split("/")
  sup_c = pathArr[0].upcase[0]
  sub_c = pathArr[1].upcase[0]
  
  curr_sup = letters[0]
  curr_sub = letters[1]
  
  if sup_c > curr_sup
    letters[0] = sup_c
  end
  if sub_c > curr_sub.upcase
    letters[1] = sub_c.downcase
  end
  return letters
end

def make_SQL_like(field,match_string,options={})
  options[:not_char] ||= "^"
  options[:prefix] ||= ""
  options[:suffix] ||= ""
  not_char = options[:not_char]
  prefix = options[:prefix]
  suffix = options[:suffix]
  r = ""
  if match_string.start_with? not_char
    r = "#{field} NOT LIKE '#{prefix}#{match_string[1..-1]}#{suffix}'"
  else
    r = "#{field} LIKE '#{prefix}#{match_string}#{suffix}'"
  end
end

def copy_to_clipboard(str)
  pb = NSPasteboard.generalPasteboard
  types = [NSStringPboardType];
  pb.declareTypes(types, :owner => self)
  pb.setString(str, :forType => NSStringPboardType)
end

def get_selected(popup,old_selected,unselectable="---")
  selected = catalog_list.titleOfSelectedItem
  if selected == unselectable and old_selected != unselectable
    selected = old_selected
    catalog_list.selectItemWithTitle selected
  else
    yield selected if block_given?
  end
  return selected
end

def set_list_value(list,values,nil_value=nil)
  values.unshift(nil_value) if nil_value
  list.removeAllItems
  puts "a"
  list.addItemsWithTitles values
  puts "b"
  return list.titleOfSelectedItem
end

def filenames(path,ext)
  ls_list = Dir["#{path}*.#{ext}"].select {|f| !File.directory? f}
  ls_list.map {|f| File.basename(f,".#{ext}")}
end

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

def constructSQL(table,and_conds,or_conds=[])
  conds = []
  and_string = and_conds.join(" AND ")
  or_string = or_conds.join(" OR ")
  if or_string != ""
    or_string = " AND #{or_string}"
  end
  if and_conds.empty? and or_conds.empty?
    sql = "SELECT * FROM #{table.sqlescape}"
  else
    sql = "SELECT * FROM #{table.sqlescape} WHERE #{and_string} #{or_string}"
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