########################################################################
# File:    loader_helper.rb                                            #
#          Based on work by Hipposoft 2008                             #
#                                                                      #
# Purpose: Support functions for views related to Task Import objects. #
#          See controllers/loader_controller.rb for more.              #
#                                                                      #
# History: 04-Jan-2008 (ADH): Created.                                 #
#          Feb 2009 (SJS): Hacked into plugin for redmine              #
########################################################################

module LoaderHelper

  # Generate a project selector for the project to which imported tasks will
  # be assigned. HTML is output which is suitable for inclusion in a table
  # cell or other similar container. Pass the form object being used for the
  # task import view.

  def loaderhelp_project_selector( form )
    projectlist = Project.find :all, :conditions => Project.visible_by(User.current)

    unless( projectlist.empty? )
      output  = "        &nbsp;Project to which all tasks will be assigned:\n"
      output  << "<select id=\"import_project_id\" name=\"import[project_id]\"><optgroup label=\"Your Projects\"> "

      projectlist.each do | projinfo |

        output = output + "<option value=\"" + projinfo.id.to_s + "\">" + projinfo.to_s + "</option>"

      end
      output << "</optgroup>"
      output << "</select>"


    else
      output  = "        There are no projects defined. You can create new\n"
      output << "        projects #{ link_to( 'here', '/project/new' ) }."
    end

    output.html_safe
  end

  # Generate a category selector to which imported tasks will
  # be assigned. HTML is output which is suitable for inclusion in a table
  # cell or other similar container. Pass the form object being used for the
  # task import view.

  def loaderhelp_category_selector( fieldId, project, allNewCategories, requestedCategory )

    # First populate the selection box with all the existing categories from this project
    existingCategoryList = IssueCategory.find :all, :conditions => { :project_id => project }

    output = "<select id=\"" + fieldId + "\" name=\"" + fieldId + "\"> "
    # Empty entry
    output << "<option value=\"\"></option>"
    output << "<optgroup label=\"Existing Categories\"> "

    existingCategoryList.each do | category_info |
      if ( category_info.to_s == requestedCategory )
        output << "<option value=\"" + category_info.to_s + "\" selected=\"selected\">" + category_info.to_s + "</option>"
      else
        output << "<option value=\"" + category_info.to_s + "\">" + category_info.to_s + "</option>"
      end
    end

    output << "</optgroup>"

    # Now add any new categories that we found in the project file
    #output << "<optgroup label=\"New Categories\"> "

    #allNewCategories.each do | category_name |
    #  if ( not existingCategoryList.include?(category_name) )
    #    if ( category_name == requestedCategory )
    #      output << "<option value=\"" + category_name + "\" selected=\"selected\">" + category_name + "</option>"
    #    else
    #      output << "<option value=\"" + category_name + "\">" + category_name + "</option>"
    #    end
    #  end
    #end

    #output << "</optgroup>"

    output << "</select>"

    return output.html_safe
  end

  # Generate a user selector to which imported tasks will
  # be assigned. HTML is output which is suitable for inclusion in a table
  # cell or other similar container. Pass the form object being used for the
  # task import view.

  def loaderhelp_user_selector( fieldId, project, assigned_to )
    # First populate the selection box with all the existing categories from this project
    userList = Member.where(:project_id => project).all.map(&:user).sort_by(&:name).compact

    output = "<select id=\"" + fieldId + "\" name=\"" + fieldId + "\">"

    # Empty entry
    output << "<option value=\"\"></option>"

    # Add all the users
    userList.each do | user_entry |
      output << "<option value=\"" + user_entry.id.to_s + "\""
      output << " selected='selected' " if assigned_to == user_entry.id
      output << " >" + user_entry.name + "</option>"
    end

    output << "</select>"

    return output.html_safe
  end

  def loaderhelp_tracker_selector( fieldId, project, tracker_name )
    output = "<select id=\"" + fieldId + "\" name=\"" + fieldId + "\">"

    # Empty entry
    output << "<option value=\"\"></option>"

    # Add all the trackers
    project.trackers.each do |tracker|
      output << "<option value=\"#{tracker.id}\""
      output << " selected='selected' " if tracker.name == tracker_name
      output << " >" + tracker.name + "</option>"
    end

    output << "</select>"

    return output.html_safe
  end
end
