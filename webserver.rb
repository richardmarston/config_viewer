#!/usr/bin/ruby

require 'socket'
$test=false
require_relative 'database.rb'

$debug=true

def add_labelled_input(para, name)
   label = Element.new('LABEL')
   label.add_attribute('for', name.downcase)
   label.add_text(name)
   entry = Element.new('INPUT')
   entry.add_attribute('type', 'text')
   entry.add_attribute('name', name.downcase)
   entry.add_attribute('value', 'haha')
   para.add(label) 
   para.add(entry)
   para.add(Element.new('BR'))
end

def showLink(link)
   h2 = Element.new('h2')
   link_html = Element.new('a')
   link_html.add_attribute('href', '/link/'+link.attribute('name').to_s)
   link_html.add_text(link.attribute('name').to_s)
   p = Element.new('p')
   p.add_text(link.attribute('command').to_s)
   h2 << link_html
   h2 << p
   h2
end

def showChain(chain_name)
   db = Database.new
   html = Element.new('html')
   html.add_attribute('lang','en')
   body = Element.new('body')
   title = body << Element.new('title')
   title.add_text('Chain: '+chain_name)
   address = chain_name.split('/')

   if(address.length == 2)
      content = db.readDefinitions
      xpath = '//config//chain[@name="'+address[1]+'"]'
      XPath.each(content, xpath) { | chain | 
         chain.each_element { | link |
            body << showLink(link)
         }
         body << Element.new('br')
      }
   end
   html << body
   html
end

def createMenu()
   db = Database.new
   html = Element.new('html')
   html.add_attribute('lang','en')
   body = Element.new('body')
   title = body << Element.new('title')
   title.add_text('Chains')

   content = db.readDefinitions
   content.each_element { | config |
      config.each_element { | chain |
         h1 = Element.new('h1')
         body << h1
         a = Element.new('a')
         a.add_attribute('href', '/chain/'+chain.attribute('name').to_s)
         a.add_text(chain.attribute('name').to_s)
         body << a 
         body << Element.new('br')
         chain.each_element { | link |
            body << showLink(link)
         }
         body << Element.new('br')
      }
   }
   html << body
   html
end

def newEntryForm(document)
   form = Element.new('FORM')
   form.add_attribute('action', 'http://127.0.0.1:7125/submit.html')
   form.add_attribute('method', 'post')
   para = Element.new('P')
   add_labelled_input(para, 'Name')
   add_labelled_input(para, 'Command')

   send_button = Element.new('INPUT')
   send_button.add_attribute('type', 'submit')
   send_button.add_attribute('value','Add')

   para << send_button
   form << para
   document << form 
end

def newFileTemplate(session)
    session.print()
end

def readData(session)
   content=nil
   request = session.gets
   while (request != "\r\n")
      request = session.gets
      puts "request: "+request.to_s unless $debug == false
      if request.match('Content-Length: ')
         content_length = request.to_s[16, request.length]
         puts "content_length: "+content_length unless $debug == false
         request = session.read(2)
         content = session.read(content_length.to_i)
         puts "content: "+content unless $debug == false
      end
   end
   content
end

def doGet(session, request)
   getrequest = request.gsub(/GET\ \//, '').gsub(/\ HTTP.*/, '')
   filename = getrequest.chomp
   document = Document.new
   if filename == ""
      document << createMenu()
      #newEntryForm(document)
   else
      #filename = "newFileTemplate.html"
      document << showChain(filename)
   end
   data=readData session
   if data != nil
      puts "data: "+data
   end
   puts "DOC: "+document.to_s
   document
end

def doPost(session, request)
   document = Document.new
   postrequest = request.gsub(/POST\ \//, '').gsub(/\ HTTP.*/, '')
   puts "postrequest: "+request.to_s unless $debug == false
   data=readData session
   if data != nil
      puts "data: "+data
   end
   document
end

webserver = TCPServer.new('127.0.0.1', 7125)
while (session = webserver.accept)
   request = session.gets
   puts request unless $debug == false

   filename = ""
   if (request.match("GET\ "))
      document=doGet(session,request)
   elsif (request.match("POST\ "))
      document=doPost(session,request)
   end
   
   session.print "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
   session.print document
   session.close

   puts "done" unless $debug == false

   #if (filename != "")
   #   begin
   #      displayfile = File.open(filename, 'r')
   #      content = displayfile.read()
   #      session.print content
   #   rescue Errno::ENOENT
   #      session.print "File not found"
   #   end
   #end
end
