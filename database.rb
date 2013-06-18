#!/usr/bin/ruby

require 'rexml/document'
include REXML
$debug = false

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

   def addLink(chain_name, link_name, command)
      must_be_unique=true
      config = @document.root()
      chain = addElement(config, 'chain', chain_name)
      link = addElement(chain, 'link', link_name, must_be_unique)
      link.add_attribute('command', command)
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
