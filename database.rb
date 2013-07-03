#!/usr/bin/ruby

require 'rexml/document'
require 'cgi'
include REXML
$debug = false

class ChainLink
   attr_accessor :name, :config, :log, :chain
   def initialize(_name, _log, _config, _chain)
      @name    = _name    == nil ? "":_name
      @log     = _log     == nil ? "":_log
      @config  = _config  == nil ? "":_config
      @chain   = _chain   == nil ? "":_chain
   end
   def to_s
      'ChainLink.to_s! '+ @name + " " + @log + " " + @config + " " + @chain
   end
end

class Database
   def initialize()
      @filename = "config.xml"
      @definitions = readDefinitions
   end

   def getElementIfExistant(node,element_type,name_attribute)
      node.each_element('//'+element_type) { | element |
         if (name_attribute == element.attribute('name').to_s)
            return element 
         end
      }
      return nil
   end

   def addElement(node,element_type,name_attribute,must_be_unique=false)
      element = getElementIfExistant(node,element_type,name_attribute)
      if (element == nil)
         new_element = Element.new(element_type)
         new_element.add_attribute('name',name_attribute)
         node << new_element
         return new_element
      else
         if (must_be_unique)
            raise 'Could not add unique element'
         else
            return element
         end
      end
   end

   def addLink(chainlink)
      puts 'addLink called: '+ chainlink.to_s
      must_be_unique=true
      config = @document.root()
      chain = addElement(config, 'chain', chainlink.chain)
      link = addElement(chain, 'link', chainlink.name, must_be_unique)
      link.add_attribute('log', chainlink.log)
      link.add_attribute('config', chainlink.config)
      puts @document
   end

   def saveDefinitions(filename=@filename)
      file = File.open(filename, 'w')
      file.write(@document)
      file.close()
   end

   def readDefinitions
      file = File.open(@filename, 'r')
      @document = Document.new file
      file.close()
      @document
   end
end

def test
   db = Database.new
   db.readDefinitions
   begin
      db.addLink('mychain', 'my_new_source', 'ssh rich-tpad -x cat /tmp/my3.xml')
      db.addLink('otherchain', 'other_third_source', 'ssh rich-tpad -x cat /tmp/other3.xml')
      db.addLink('otherchain', 'other_third_source', 'ssh rich-tpad -x cat /tmp/other3.xml')
   rescue
      puts "Exception caught"
   end
   db.saveDefinitions('config_output.xml')
end

# $test is defined in including file
test unless $test==false
