# This module defines stub classes for testing the instantiation methods of Ydl.
# They are not part of the application.
module LawDoc
  # Stub class to represent a generic person, natural or juridical.
  class Person
    attr_reader :sex, :hon, :first, :middle, :last, :name
    attr_reader :address, :phone, :fax, :email

    def initialize(sex: 'entity',
                   hon: nil,
                   first: nil,
                   last: nil,
                   middle: nil,
                   suffix: nil,
                   name: nil,
                   address: nil,
                   phone: nil,
                   fax: nil,
                   email: nil)
      @sex ||= sex.clean.downcase
      msg = "invalid sex: '#{@sex}'"
      raise ArgumentError, msg unless %w[entity male female].include?(@sex)

      @hon = hon
      @first = first
      @middle = middle
      @last = last
      @suffix = suffix
      msg = 'set name only for entities; use name components otherwise'
      raise ArgumentError, msg if name && @sex != 'entity'

      @address = init_address(address)
      @phone = init_phone(phone)
      @fax = init_phone(fax, field: 'fax')
      @name = name
      @email = email
    end

    def init_address(addr, field: 'address')
      case addr
      when Address, NilClass
        @address = addr
      when Hash
        @address = Address.new(addr)
      else
        msg = "cannot initialize #{field} with #{addr.class.name}"
        raise ArgumentError, msg
      end
    end

    def init_phone(phn, field: 'phone')
      case phn
      when Phone, NilClass
        @phone = phn
      when String
        @phone = Phone.new(phn)
      else
        msg = "cannot initialize #{field} with #{phn.class.name}"
        raise ArgumentError, msg
      end
    end

    def self.from_hash(hsh)
      Person.new(hsh)
    end

    def to_h
      {
        sex: sex, hon: hon, first: first, last: last, middle: middle,
        name: name, address: address, phone: phone, fax: fax, email: email
      }
    end
  end

  class Address
    def initialize(
          street: nil,
          city: nil,
          state: nil,
          zip: nil,
          country: 'United States')
      case street
      when String
        @street = [street.to_s]
      when Array
        @street = street.map(&:to_s)
      end
      @city = city
      @state = state
      @zip = zip.to_s
      @country = country
    end
  end

  class Phone
    def initialize(str)
      @phone = str
    end
  end

  class Party < Person
    attr_reader :role, :lawyers

    def initialize(role: nil, lawyers: [], **other)
      if other.key?(:person)
        if other[:person].is_a?(Person)
          person_params = other[:person].to_h
          other.delete(:person)
          super(other.merge(person_params))
        elsif other[:person].is_a?(Hash)
          person_params = other[:person]
          other.delete(:person)
          super(other.merge(person_params))
        end
      else
        super(other)
      end
      @role = role
      case lawyers
      when Lawyer
        @lawyers = [lawyers]
      when Array
        unless lawyers.all? { |l| l.is_a?(Lawyer) || l.is_a?(Hash) }
          raise ArgumentError, 'lawyers array must be Lawyer objects'
        end
        @lawyers = lawyers.map do |l|
          case l
          when Lawyer
            l
          when Hash
            Lawyer.new(l)
          end
        end
      when NilClass
        @lawyers = []
      else
        raise ArgumentError,
              "cannot initialize lawyers with #{lawyers.class.name}"
      end
    end
  end

  class Lawyer < Person
    attr_reader :bar_numbers, :esig, :sig

    def initialize(bar_numbers: {},
                   esig: nil,
                   sig: nil,
                   **other)
      super(other)
      @bar_numbers = bar_numbers
      @esig = esig
      @sig = sig
    end
  end

  class Judge < Person
    attr_reader :title, :initials

    def initialize(initials: nil,
                   title: nil,
                   **other)
      super(other)
      @initials = initials
      @title = title
    end
  end

  class Court < Person
    def initialize(**other)
      other[:sex] = 'entity'
      super(other)
    end
  end

  class Case
    attr_reader :parties
    def initialize(number: nil,
                   complaint_date: nil,
                   court: nil,
                   judge: nil,
                   parties: [])
      @number = number.to_s
      @complaint_date = complaint_date
      case court
      when Court
        @court = court
      when Hash
        @court = Court.new(court)
      when NilClass
        @court = nil
      else
        raise ArgumentError, "court of class #{court.class} invalid"
      end
      case judge
      when Judge
        @judge = judge
      when Hash
        @judge = Judge.new(judge)
      when NilClass
        @judge = nil
      else
        raise ArgumentError, "judge of class #{judge.class} invalid"
      end
      @parties = parties
    end
  end
end
