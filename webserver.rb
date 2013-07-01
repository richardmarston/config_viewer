#!/usr/bin/ruby

require 'socket'
$test=false

if (RUBY_VERSION=="1.9.3")
   require_relative 'database.rb'
else
   require 'database.rb'
end


$debug=true

def showLink(chain, link)
   h2 = Element.new('h2')
   link_html = Element.new('a')
   link_html.add_attribute('href', '/chain/'+link.attribute('name').to_s)
   link_html.add_text(link.attribute('name').to_s)
   p = Element.new('p')
   button = Element.new('button')
   button.add_attribute('type', 'button')
   button.add_text(link.attribute('name').to_s)
   button.add_attribute('type', 'submit')
   form = Element.new('FORM')
   form.add_attribute('action', 'http://127.0.0.1:7125/chain/'+chain+'/link/'+link.attribute('name').to_s)
   form.add_attribute('method', 'get')
   form << button
   p << form
   h2 << link_html
   h2 << p
   h2
end

def showLog(link)
   textArea = Element.new('textarea')
   puts 'executing: '+link.attribute('command').to_s
   filldata = `#{link.attribute('command').to_s}`
   puts (filldata)
   textArea.add_text(filldata) 
end

def showChain(chain_name, link_name='')
   db = Database.new
   html = Element.new('html')
   html.add_attribute('lang','en')
   body = Element.new('body')
   title = body << Element.new('title')
   title.add_text('Chain: '+chain_name)

   content = db.readDefinitions
   xpath = '//config//chain[@name="'+chain_name+'"]'
   XPath.each(content, xpath) { | chain | 
      chain.each_element { | link |
         body << showLink(chain_name, link)
         if (link_name == link.attribute('name').to_s)
            body << showLog(link) 
         end
      }
      body << Element.new('br')
   }
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
         chain_name=chain.attribute('name').to_s
         h1 = Element.new('h1')
         body << h1
         a = Element.new('a')
         a.add_attribute('href', '/chain/'+chain_name)
         a.add_text(chain_name)
         body << a 
         body << Element.new('br')
         chain.each_element { | link |
            body << showLink(chain_name, link)
         }
         body << Element.new('br')
      }
   }
   html << body
   html
end

def add_labelled_input(para, name)
   label = Element.new('LABEL')
   label.add_attribute('for', name.downcase)
   label.add_text(name)
   entry = Element.new('INPUT')
   entry.add_attribute('type', 'text')
   entry.add_attribute('name', name.downcase)
   para.add(label) 
   para.add(entry)
end

def add_hidden_input(para, name, value)
   entry = Element.new('INPUT')
   entry.add_attribute('type', 'hidden')
   entry.add_attribute('name', name)
   entry.add_attribute('value', value)
   para.add(entry)
end

def newLinkForm(chain)
   form = Element.new('FORM')
   form.add_attribute('action', 'http://127.0.0.1:7125/newLink.html')
   form.add_attribute('method', 'post')
   para = Element.new('P')
   add_labelled_input(para, 'Name')
   add_labelled_input(para, 'Command')
   add_hidden_input(para, 'chain', chain)

   send_button = Element.new('INPUT')
   send_button.add_attribute('type', 'submit')
   send_button.add_attribute('value','Add')

   para << send_button
   form << para
   form 
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
   request_url = getrequest.chomp
   document = Document.new
   data=readData session
   if data != nil
      puts "data: "+data
   end
   if request_url == ""
      document << createMenu()
   else
      request_components = request_url.split('/')
      type = request_components[0]
      name = request_components[1]
      if (type == 'chain')    
         if (request_components.length == 4)
            document << showChain(name, request_components[3])
         else    
            document << showChain(name)
         end
         document.root << newLinkForm(name)
      else
         puts 'Did not recognise request type: '+type
         return nil
      end
   end
   puts "DOC: "+document.to_s
   document
end

def newLink(link)
   puts ' name: '    + link['name'] + 
        ' chain: '   + link['chain'] +
        ' command: ' + link['command'] unless $debug == false
   db = Database.new
   _link = ChainLink.new(link['name'], link['command'], link['chain'])
   db.addLink(_link)
   db.saveDefinitions
   myfile = <<EOF
<!DOCTYPE HTML>
<html lang="en-US">
    <head>
        <meta charset="UTF-8" />
        <meta http-equiv="refresh" content="1;url=http://127.0.0.1:7125/chain/mychain" />
        <script type="text/javascript">
            window.location.href = "http://127.0.0.1:7125/chain/mychain"
        </script>
        <title>Adding chain link</title>
    </head>
    <body>
        If you are not redirected automatically, follow the <a href='http://127.0.0.1:7125/chain/mychain'>link to example</a>
    </body>
</html>
EOF
   myfile
end

def parseParameters(data)
   hash={}
   inputs = data.split('&')
   inputs.each { |input| 
      puts input
      tokens = input.split('=')
      puts tokens
      hash[tokens[0]] = CGI::unescape(tokens[1])
   }
   hash
end

def doPost(session, request)
   postrequest = request.gsub(/POST\ \//, '').gsub(/\ HTTP.*/, '')
   puts "postrequest: "+request.to_s unless $debug == false
   data=readData session
   document = nil
   if data != nil
      puts "data: "+data
      params=parseParameters(data)
      puts params
      document = Document.new newLink(params)
   end
   document
end

webserver = TCPServer.new('127.0.0.1', 7125)
while (session = webserver.accept)
   request = session.gets
   puts request unless $debug == false

   filename = ""
   if (request == nil)
      next
   end

   if (request.match("GET\ "))
      document=doGet(session,request)
   elsif (request.match("POST\ "))
      document=doPost(session,request)
   end
   
   if (document != nil)
      session.print "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
      session.print document
      session.close
   end

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
