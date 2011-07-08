module Mailboxer
  module Models
    module Messageable
      def self.included(mod)
        mod.extend(ClassMethods)
      end

      module ClassMethods
        #Converts the model into messageable allowing it to interchange messages and
        #receive notifications
        def acts_as_messageable
          has_many :messages
          has_many :receipts, :order => 'created_at DESC', :dependent => :destroy

          include Mailboxer::Models::Messageable::InstanceMethods
        end
      end

      module InstanceMethods
        #Returning any kind of indentification you want for the model
        def name
          super
        rescue NameError
          return "You should add method :name in your Messageable model"
          end

        #Returning the email address of the model
        def email
          super
        rescue NameError
          return "define_email@on_your.model"
          end

        #Returning whether an email should be sent for this object (Message or Notification)
        def should_email?(object)
          super
        rescue NameError
          return true
          end

        #Gets the mailbox of the messageable
        def mailbox
          @mailbox = Mailbox.new(self) if @mailbox.nil?
          @mailbox.type = :all
          return @mailbox
        end

        #Sends a notification to the messageable
        def notify(subject,body,object = nil)
          notification = Notification.new({:body => body, :subject => subject})
          notification.recipients = [self]
          notification.object = object if object.present?
          return notification.deliver
        end

        #Sends a messages, starting a new conversation, with the messageable
        #as originator
        def send_message(recipients, msg_body, subject)
          convo = Conversation.new({:subject => subject})
          message = Message.new({:sender => self, :conversation => convo,  :body => msg_body, :subject => subject})
          message.recipients = recipients.is_a?(Array) ? recipients : [recipients]
          message.recipients = message.recipients.uniq
          return message.deliver
        end

        #Basic reply method. USE NOT RECOMENDED.
        #Use reply_to_sender, reply_to_all and reply_to_conversation instead.
        def reply(conversation, recipients, reply_body, subject = nil)
          subject = subject || "RE: #{conversation.subject}"
          response = Message.new({:sender => self, :conversation => conversation, :body => reply_body, :subject => subject})
          response.recipients = recipients.is_a?(Array) ? recipients : [recipients]
          response.recipients = response.recipients.uniq
          response.recipients.delete(self)
          return response.deliver(true)
        end

        #Replies to the sender of the message in the conversation
        def reply_to_sender(receipt, reply_body, subject = nil)
          return reply(receipt.conversation, receipt.message.sender, reply_body, subject)
        end

        #Replies to all the recipients of the message in the conversation
        def reply_to_all(receipt, reply_body, subject = nil)
          return reply(receipt.conversation, receipt.message.recipients, reply_body, subject)
        end

        #Replies to all the recipients of the last message in the conversation and untrash any trashed message by messageable
        #if should_untrash is set to true (this is so by default)
        def reply_to_conversation(conversation, reply_body, subject = nil, should_untrash = true)
          #move conversation to inbox if it is currently in the trash and should_untrash parameter is true.
          if should_untrash && mailbox.is_trashed?(conversation)
            mailbox.receipts_for(conversation).untrash
          end
          return reply(conversation, conversation.last_message.recipients, reply_body, subject)
        end

        #Mark the object as read for messageable.
        #
        #Object can be:
        #* A Receipt
        #* A Message
        #* A Notification
        #* A Conversation
        #* An array with any of them
        def read(obj)
          case obj
          when Receipt
            return obj.mark_as_read if obj.receiver == self
          when Message, Notification
            obj.mark_as_read(self)
          when Conversation
            obj.mark_as_read(self)
          when Array
            obj.map{ |sub_obj| read(sub_obj) }
          else
          return nil
          end
        end

        #Mark the object as unread for messageable.
        #
        #Object can be:
        #* A Receipt
        #* A Message
        #* A Notification
        #* A Conversation
        #* An array with any of them
        def unread(obj)
          case obj
          when Receipt
            return obj.mark_as_unread if obj.receiver == self
          when Message, Notification
            obj.mark_as_unread(self)
          when Conversation
            obj.mark_as_unread(self)
          when Array
            obj.map{ |sub_obj| unread(sub_obj) }
          else
          return nil
          end
        end
        
        
        #Mark the object as trashed for messageable.
        #
        #Object can be:
        #* A Receipt
        #* A Message
        #* A Notification
        #* A Conversation
        #* An array with any of them
        def trash(obj)
          case obj
          when Receipt
            return obj.move_to_trash if obj.receiver == self
          when Message, Notification
            obj.move_to_trash(self)
          when Conversation
            obj.move_to_trash(self)
          when Array
            obj.map{ |sub_obj| trash(sub_obj) }
          else
          return nil
          end
        end

        #Mark the object as not trashed for messageable.
        #
        #Object can be:
        #* A Receipt
        #* A Message
        #* A Notification
        #* A Conversation
        #* An array with any of them
        def untrash(obj)
          case obj
          when Receipt
            return obj.untrash if obj.receiver == self
          when Message, Notification
            obj.untrash(self)
          when Conversation
            obj.untrash(self)
          when Array
            obj.map{ |sub_obj| untrash(sub_obj) }
          else
          return nil
          end
        end
      end
    end
  end
end