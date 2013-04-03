########################################################################
# File: loader_controler.rb # bl;a bla bla
# Hipposoft 2008 #
# #
# History: 04-Jan-2008 (ADH): Created. #
# Feb 2009 (SJS): Hacked into plugin for redmine #
########################################################################

#class TaskImport
#  @tasks = []
#  @project_id = nil
#  @new_categories = []

#  attr_accessor( :tasks, :project_id, :new_categories )
#end



class LoaderController < ApplicationController

  unloadable

  before_filter :find_project, :authorize, :only => [:new, :create]

  require 'zlib'
  require 'ostruct'
  require 'tempfile'
  require 'rexml/document'
  require 'builder/xmlmarkup'

  # This allows to update the existing task in Redmine from MS Project
  ActiveRecord::Base.lock_optimistically=false

  # Set up the import view. If there is no task data, this will consist of
  # a file entry field and nothing else. If there is parsed file data (a
  # preliminary task list), then this is included too.



  def new
    # This can and probably SHOULD be replaced with some URL rewrite magic
    # now that the project loader is Redmine project based.
    find_project()
  end

  # Take the task data from the 'new' view form and 'create' an "import
  # session"; that is, create real Task objects based on the task list and
  # add them to the database, wrapped in a single transaction so that the
  # whole operation can be unwound in case of error.

  def create
    # This can and probably SHOULD be replaced with some URL rewrite magic
    # now that the project loader is Redmine project based.
    find_project()

    # Set up a new TaskImport session object and read the XML file details

    xmlfile = params[ :import ][ :xmlfile ]
    @import = TaskImport.new

    if xmlfile.present?

      # The user selected a file to upload, so process it

      begin

        # We assume XML files always begin with "<" in the first byte and
        # if that's missing then it's GZip compressed. That's true in the
        # limited case of project files.

#        byte = xmlfile.getc()
        xmlfile.rewind()

#        xmlfile = Zlib::GzipReader.new( xmlfile ) if ( byte != '<'[ 0 ] )
#        xmldoc = REXML::Document.new( xmlfile.read )
        @import.tasks, @import.new_categories = get_tasks_from_xml( REXML::Document.new( xmlfile.read ) )

        if @import.tasks.blank?
          flash[ :error ] = 'No usable tasks were found in that file'
        else
          flash[ :notice ] = 'Tasks read successfully. Please choose items to import.'
        end

#      rescue => error

#        # REXML errors can be huge, including a full backtrace. It can cause
#        # session cookie overflow and we don't want the user to see it. Cut
#        # the message off at the first newline.

#        lines = error.message.split("\n")
#        flash[ :error ] = "Failed to read file: #{ lines[ 0 ] }"
      end

      render :action => :new
      flash.delete( :error )
      flash.delete( :notice )

    else

      # No file was specified. If there are no tasks either, complain.

      tasks = params[ :import ][ :tasks ]

      if ( tasks.blank? )
        flash[ :error ] = "Please choose a file before using the 'Analyse' button."
        render( { :action => :new } )
        flash.delete( :error )
        return
      end

      # Compile the form submission's task list into something that the
      # TaskImport object understands.
      #
      # Since we'll rebuild the tasks array inside @import, we can render the
      # 'new' view again and have the same task list presented to the user in
      # case of error.

      @import.tasks = []
      @import.new_categories = []
      to_import = []

      # Due to the way the form is constructed, 'task' will be a 2-element
      # array where the first element contains a string version of the index
      # at which we should store the entry and the second element contains
      # the hash describing the task itself.

      tasks.each do | taskinfo |
        index = taskinfo[ 0 ].to_i
        task = taskinfo[ 1 ]
        struct = OpenStruct.new(task)
        struct.predecessors = struct.predecessors.split(', ')
        struct.delays = struct.delays.split(', ')
        @import.tasks[ index ] = struct
        to_import[ index ] = struct if ( task[ :import ] == '1' )
      end

      to_import.compact!

      # The "import" button in the form causes token "import_selected" to be
      # set in the params hash. The "analyse" button causes nothing to be set.
      # If the user has clicked on the "analyse" button but we've reached this
      # point, then they didn't choose a new file yet *did* have a task list
      # available. That's strange, so raise an error.
      #
      # On the other hand, if the 'import' button *was* used but no tasks were
      # selected for error, raise a different error.

      if ( params[ :import ].nil? )
        flash[ :error ] = 'No new file was chosen for analysis. Please choose a file before using the "Analyse" button, or use the "Import" button to import tasks selected in the task list.'
      elsif ( to_import.empty? )
        flash[ :error ] = 'No tasks were selected for import. Please select at least one task and try again.'
      end

      # Get defaults to use for all tasks - sure there is a nicer ruby way, but this works
      #
      # Tracker
      default_tracker_name = Setting.plugin_redmine_loader['tracker']
      default_tracker = Tracker.find_by_name(default_tracker_name)
      default_tracker_id = default_tracker.try(:id)

      if ( default_tracker_id.nil? )
        flash[ :error ] = 'No valid default Tracker. Please ask your System Administrator to resolve this.'
      end

      # Bail out if we have errors to report.
      unless( flash[ :error ].nil? )
        render( { :action => :new } )
        flash.delete( :error )
        return
      end

      # We're going to keep track of new issue ID's to make dependencies work later
      uidToIssueIdMap = {}
      # keep track of new Version ID's
      uidToVersionIdMap = {}
      # keep track of the outlineNumbers to set the parent_id
      outlineNumberToIssueIDMap = {}

      imported = 0

      # Right, good to go! Do the import.
      begin
        Issue.transaction do
          to_import.sort_by{ |s| s.outlinenumber.split('.').map(&:to_i) }.each do | source_issue |

            # We comment those lines becouse they are not necesary now.
            # Add the category entry if necessary
            #category_entry = IssueCategory.find :first, :conditions => { :project_id => @project.id, :name => source_issue.category }
            logger.error "DEBUG: Issue to be imported: #{source_issue.inspect}"
            if source_issue.category.present?
              logger.error "DEBUG: Search category id by name: #{source_issue.category}"
              category_entry = IssueCategory.find_by_project_id_and_name(@project.id, source_issue.category)
              logger.error "DEBUG: Category found: #{category_entry.inspect}"
            else
              category_entry = nil
            end

            if source_issue.tracker_id.present?
               logger.error "DEBUG: Search tracker id by name: #{source_issue.tracker_name}"
#               final_tracker = Tracker.find(:first, :conditions => [ "name = ?", source_issue.tracker_name])
               final_tracker = Tracker.find_by_id(source_issue.tracker_id)
               logger.error "DEBUG: Tracker found: #{category_entry.inspect}"
            else
              final_tracker = default_tracker
            end
            final_tracker = default_tracker if final_tracker.nil?

            if (source_issue.milestone.to_i == 0)
              destination_issue = Issue.find_by_project_id_and_uid(@project.id, source_issue.uid) || Issue.new
              destination_issue.tracker_id = final_tracker.id
              destination_issue.uid = source_issue.uid.to_i
              destination_issue.category_id = category_entry.try(:id)
              destination_issue.subject = source_issue.title.slice(0, 255) # Max length of this field is 255
              destination_issue.estimated_hours = source_issue.duration
              destination_issue.project_id = @project.id
              destination_issue.author_id = User.current.id
              destination_issue.lock_version = 0
              destination_issue.done_ratio = source_issue.percentcomplete
              destination_issue.start_date = source_issue.start
              destination_issue.due_date = source_issue.finish || destination_issue.start_date + ((source_issue.duration.to_f/40.0)*7.0).to_i
              destination_issue.description = source_issue.notes

#              logger.error "DEBUG: Assigned_to field: #{source_issue.assigned_to}"
              destination_issue.assigned_to = User.find_by_id(source_issue.assigned_to)
              imported += 1 if destination_issue.save

              logger.error "DEBUG: Issue imported: #{destination_issue.inspect}"
#              logger.error "DEBUG: Issue #{destination_issue.description} imported"
              # Now that we know this issue's Redmine issue ID, save it off for later
              uidToIssueIdMap[ source_issue.uid ] = destination_issue.id
              #Save the Issue's ID with the outlineNumber as an index, to set the parent_id later
              outlineNumberToIssueIDMap[ source_issue.outlinenumber ] = destination_issue.id
            else
              #If the issue is a milestone we save it as a Redmine Version
              version_record = Version.find_by_project_id_and_uid(@project.id, source_issue.uid) || Version.new
              version_record.name = source_issue.title.slice(0, 59)#maximum is 60 characters
              version_record.uid = source_issue.uid.to_i
              version_record.description = source_issue.notes if source_issue.notes.present?
              version_record.effective_date = source_issue.start
              version_record.project_id = @project.id
              imported += 1 if version_record.save
              # Store the version_record.id  to assign the issues to the version later
              uidToVersionIdMap[ source_issue.uid ] = version_record.id
            end
          end

          flash[ :notice ] = "#{ imported } #{ to_import.length == 1 ? 'task' : 'tasks' } imported successfully."
        end

        # Set the parent_id. We use the outnum of the issue (the outlineNumber without the last .#).
        # This outnum is the same as the parent's outlineNumber, so we can use it as the index of the
        # outlineNumberToIssueIDMap to get the parent's ID
        Issue.transaction do
          to_import.each do | source_issue |
            if destination_issue = Issue.find_by_project_id_and_uid(@project.id, source_issue.uid)
              destination_issue.parent_issue_id = Issue.find_by_project_id_and_uid(@project.id, source_issue.parent_uid).try(:id)
              destination_issue.save(:validate => false)
            end
         end
        end

        # Delete all the relations off the issues that we are going to import. If they continue existing we are going to create them. If not they must be deleted.
        to_import.each do | source_issue |
          IssueRelation.delete_all(["issue_to_id =?", uidToIssueIdMap[source_issue.uid]])
        end

        # Handle all the dependencies being careful if the parent doesn't exist
        IssueRelation.transaction do
          to_import.each do | source_issue |
            delaynumber = 0
            source_issue.predecessors.each do | parent_uid |
              # Parent is being imported also. Go ahead and add the association
              if ( uidToIssueIdMap.has_key?(parent_uid) )
                # If the issue is not a milestone we have to create the issue relation
                if (source_issue.milestone.to_i == 0)
                  relation_record = IssueRelation.new do |i|
                    i.issue_from_id = uidToIssueIdMap[parent_uid]
                    i.issue_to_id = uidToIssueIdMap[source_issue.uid]
                    i.relation_type = 'precedes'
                    # Set the delay of the relation if it exists.
                    if source_issue.delays[delaynumber].present?
#                      if source_issue.delays[delaynumber].to_i > 0
                        i.delay = (source_issue.delays[delaynumber].to_i)/4800
                        delaynumber = delaynumber + 1
#                      end
                    end
                  end
                  logger.error "DEBUG: #{relation_record.inspect}" unless relation_record.save(:validation => false)
                else
                  # If the issue is a milestone we have to assign the predecessor to the version
                  destination_issue = Issue.find(:first, :conditions => ["project_id =? AND id=?", @project.id, uidToIssueIdMap[parent_uid]])
                  destination_issue.fixed_version_id = uidToVersionIdMap[source_issue.uid]
                  logger.error "DEBUG: #{destination_issue.inspect}" unless destination_issue.save(:validation => false)
                end
              end
            end
          end
        end


        redirect_to( "/projects/#{@project.identifier}/issues" )


#        rescue => error
#        flash[ :error ] = "Unable to import tasks: #{ error }"
#        logger.error "DEBUG: Unable to import tasks: #{ error }"
#        render( { :action => :new } )

      end
    end
  end

  private

  def find_project
    # @project variable must be set before calling the authorize filter
    @project = Project.find(params[:project_id])
  end

  # Look if the issue is parent of another issue or not
  def is_parent(issue_id)
    Issue.find(:first, :conditions =>["parent_id=?", issue_id])
  end

  # Obtain a task list from the given parsed XML data (a REXML document).

  def get_tasks_from_xml( doc )

    # Extract details of every task into a flat array
    tasks = []

    logger.error "DEBUG: BEGIN get_tasks_from_xml"

    tracker_alias = Setting.plugin_redmine_loader['tracker_alias'].force_encoding "UTF-8"
    tracker_field_id = nil;
    #FIXME Надо проверить как оно работает
    doc.each_element( "Project/ExtendedAttributes/ExtendedAttribute[Alias='#{tracker_alias}']/FieldID") do | ext_attr |
      tracker_field_id = ext_attr.text.to_i;
    end

    doc.each_element( 'Project/Tasks/Task' ) do | task |
      begin
        logger.error "Project/Tasks/Task found"
        struct = OpenStruct.new
        struct.level = task.get_elements( 'OutlineLevel' )[0].text.to_i if task.get_elements('OutlineLevel')[0]
        struct.outlinenumber = task.get_elements('OutlineNumber')[0].text.strip if task.get_elements('OutlineNumber')[0]

        if auxString = struct.outlinenumber
          index = auxString.rindex('.')
          if index
            index -= 1
            struct.outnum = auxString[0..index]
          end
        end

        struct.tid = task.get_elements('ID')[0].text.to_i if task.get_elements('ID')[0]
        struct.uid = task.get_elements('UID')[0].text.to_i if task.get_elements('UID')[0]
        struct.title = task.get_elements('Name')[0].text.strip if task.get_elements('Name')[0]
        struct.start = task.get_elements('Start')[0].text.split("T")[0] if task.get_elements('Start')[0]
        struct.finish = task.get_elements('Finish')[0].text.split("T")[0] if task.get_elements('Finish')[0]

        s1 = task.get_elements('Start')[0].text.strip if task.get_elements('Start')[0]
        s2 = task.get_elements('Finish')[0].text.strip if task.get_elements('Finish')[0]

        task.each_element( "ExtendedAttribute[FieldID='#{tracker_field_id}']/Value") do | tracker_value |
          struct.tracker_name = tracker_value.text
        end

        # If the start date and the finish date are the same it is a milestone
        struct.milestone = (s1 == s2) ? 1 : 0

        struct.percentcomplete = task.get_elements( 'PercentComplete')[0].text.to_i
        struct.notes = task.get_elements( 'Notes' )[ 0 ].text.strip if task.get_elements( 'Notes' )[0]
        struct.predecessors = []
        struct.delays = []
        task.each_element( 'PredecessorLink' ) do | predecessor |
        begin
          struct.predecessors.push( predecessor.get_elements('PredecessorUID')[0].text.to_i )
          struct.delays.push( predecessor.get_elements('LinkLag')[0].text.to_i )
        end
      end

      tasks.push( struct )
      #rescue
#      rescue => error
#        # Ignore errors; they tend to indicate malformed tasks, or at least,
#        # XML file task entries that we do not understand.
#        logger.error "DEBUG: Unrecovered error getting tasks: #{error}"
      end
    end

    # Sort the array by ID. By sorting the array this way, the order
    # order will match the task order displayed to the user in the
    # project editor software which generated the XML file.

    tasks = tasks.sort_by { | task | task.tid }

    outlinenumber2UID = tasks.group_by(&:outlinenumber)

    # Step through the sorted tasks. Each time we find one where the
    # *next* task has an outline level greater than the current task,
    # then the current task MUST be a summary. Record its name and
    # blank out the task from the array. Otherwise, use whatever
    # summary name was most recently found (if any) as a name prefix.

    all_categories = []
    category = ''

    tasks.each_index do | index |
      task = tasks[ index ]
      next_task = tasks[ index + 1 ]

      # Instead of deleting the sumary tasks I only delete the task 0 (the project)

      #if ( next_task and next_task.level > task.level )
      #  category = task.title.strip.gsub(/:$/, '') unless task.title.nil? # Kill any trailing :'s which are common in some project files
      #  all_categories.push(category) # Keep track of all categories so we know which ones might need to be added
        #tasks[ index ] = "Prueba"
      if task.level == 0
        category = task.title.strip.gsub(/:$/, '') if task.title.present? # Kill any trailing :'s which are common in some project files
        all_categories.push(category) # Keep track of all categories so we know which ones might need to be added
        tasks[ index ] = nil
      else
        task.category = category
      end
    end

    # Remove any 'nil' items we created above. Add parent_uid field
    tasks = tasks.compact.uniq.map do |task|
      task.parent_uid = outlinenumber2UID[task.outnum][0].uid if outlinenumber2UID[task.outnum].present?
      task
    end

    # Now create a secondary array, where the UID of any given task is
    # the array index at which it can be found. This is just to make
    # looking up tasks by UID really easy, rather than faffing around
    # with "tasks.find { | task | task.uid = <whatever> }".

    uid_tasks = []

    tasks.each do | task |
      uid_tasks[ task.uid ] = task
    end

    # OK, now it's time to parse the assignments into some meaningful
    # array. These will become our redmine issues. Assignments
    # which relate to empty elements in "uid_tasks" or which have zero
    # work are associated with tasks which are either summaries or
    # milestones. Ignore both types.

    real_tasks = []

    #doc.each_element( 'Project/Assignments/Assignment' ) do | as |
    #  task_uid = as.get_elements( 'TaskUID' )[ 0 ].text.to_i
    #  task = uid_tasks[ task_uid ] unless task_uid.nil?
    #  next if ( task.nil? )

    #  work = as.get_elements( 'Work' )[ 0 ].text
      # Parse the "Work" string: "PT<num>H<num>M<num>S", but with some
      # leniency to allow any data before or after the H/M/S stuff.
    #  hours = 0
    #  mins = 0
    #  secs = 0

    #  strs = work.scan(/.*?(\d+)H(\d+)M(\d+)S.*?/).flatten unless work.nil?
    #  hours, mins, secs = strs.map { | str | str.to_i } unless strs.nil?

      #next if ( hours == 0 and mins == 0 and secs == 0 )

      # Woohoo, real task!

    #  task.duration = ( ( ( hours * 3600 ) + ( mins * 60 ) + secs ) / 3600 ).prec_f

    #  real_tasks.push( task )
    #end

    set_assignment_to_task(doc,uid_tasks)

    logger.error "DEBUG: Real tasks: #{real_tasks.inspect}"
    logger.error "DEBUG: Tasks: #{tasks.inspect}"

    real_tasks = tasks if real_tasks.empty?

    real_tasks = real_tasks.uniq if real_tasks.present?
    all_categories = all_categories.uniq.sort

    logger.error "DEBUG: END get_tasks_from_xml"

    return real_tasks, all_categories
  end

  NOT_USER_ASSIGNED = -65535

  def set_assignment_to_task(doc,uid_tasks)

    #TODO: Are there any form to improve performance of this method ?
    resource_by_user = get_bind_resource_users(doc)

    doc.each_element( 'Project/Assignments/Assignment' ) do | as |
      task_uid = as.get_elements( 'TaskUID' ).first.text.to_i
      task = uid_tasks[ task_uid ] if task_uid.present?
      next if ( task.nil? )

      resource_id = as.get_elements('ResourceUID').first.text.to_i
      next if (resource_id == NOT_USER_ASSIGNED)

      task.assigned_to = resource_by_user[resource_id]
    end

  end

  def get_bind_resource_users(doc)
    resources = get_resources(doc)
    users_list = get_user_list_for_project
    resource_by_user = {}

    resources.each do |uid,name|
      user_found = users_list.select { |user| user.name == name }
      next if (user_found.first.nil?)
      resource_by_user[uid] = user_found.first.id
    end
    resource_by_user
  end

  def get_user_list_for_project()
    Member.find(:all, :conditions => { :project_id => @project.id }).select(&:user).map(&:user)
  end

  def get_resources(doc)
    resources = {}

    doc.each_element( 'Project/Resources/Resource' ) do | as |
      resource_uid = as.get_elements('UID').first.text.to_i
      resource_name_element = as.get_elements('Name').first;

      next if (resource_uid == 0 or resource_name_element.nil?)

      resources[resource_uid] = resource_name_element.text
    end
    resources
  end
end
