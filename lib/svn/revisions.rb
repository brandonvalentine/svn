require 'time'
require 'rubygems'
require 'ffi'

module Svn #:nodoc:

  LOG_PROP_NAME = 'svn:log'
  AUTHOR_PROP_NAME = 'svn:author'
  TIMESTAMP_PROP_NAME = 'svn:date'

  class Revision < Root

    attr_reader :num
    attr_reader :fs

    def initialize( ptr, fs, pool )
      super( ptr )
      @fs = fs
      @pool = pool
      @num = revnum
    end

    def to_i
      @num
    end

    module C
      extend FFI::Library
      ffi_lib 'libsvn_fs-1.so.1'

      typedef :pointer, :out_pointer
      typedef Pool, :pool
      typedef CError.by_ref, :error
      typedef Root, :root
      typedef :long, :revnum
      typedef :string, :name
      typedef Repo::FileSystem, :fs
      typedef CountedString, :counted_string

      attach_function :revnum,
          :svn_fs_revision_root_revision,
          [ :root ],
          :revnum

      attach_function :prop,
          :svn_fs_revision_prop,
          [ :out_pointer, :fs, :revnum, :name, :pool ],
          :error

      attach_function :proplist,
          :svn_fs_revision_proplist,
          [ :out_pointer, :fs, :revnum, :pool ],
          :error
    end

    # use the C module for all bound methods
    bind_to C

    # gets the numeric identifier for this revision
    bind :revnum
    private :revnum

    # returns the revision property +name+
    bind( :prop,
        :returning => CountedString,
        :before_return => :to_s,
        :validate => Error.return_check
      ) { |out, this, name| [ out, fs, num, name, pool ] }

    # returns a hash of revision properties
    bind( :props, :to => :proplist,
        :returning => AprHash.factory( :string, [:pointer, :string] ),
        :before_return => :to_h,
        :validate => Error.return_check
      ) { |out, this| [ out, fs, num, pool ] }

    def message
      prop( LOG_PROP_NAME )
    end
    alias_method :log, :message

    def author
      prop( AUTHOR_PROP_NAME )
    end

    def timestamp
      Time.parse( prop( TIMESTAMP_PROP_NAME ) )
    end

  end

end
