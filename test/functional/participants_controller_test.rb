require File.dirname(__FILE__) + '/../test_helper'
require 'participants_controller'
require 'users_controller'

class ParticipantsController; def rescue_action(e) raise e end; end

#This controller test requires the fixtures from the below listed files
class ParticipantsControllerTest < ActionController::TestCase
  fixtures :participants
  fixtures :courses
  fixtures :assignments
  fixtures :users
  fixtures :response_maps
  fixtures :teams_users

# Have a setup function before each test and set the default model, controller
# among other things like setting up the session id to that of a superuser.
# This is done inorder to ensure that all operations tested have the necessary
# permissions.

  def setup
    @model = Participant
    @controller = ParticipantsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @request.session[:user] = User.find(users(:superadmin).id )
    roleid = User.find(users(:superadmin).id).role_id
    Role.rebuild_cache

    Role.find(roleid).cache[:credentials]
    @request.session[:credentials] = Role.find(roleid).cache[:credentials]
    # Work around a bug that causes session[:credentials] to become a YAML Object
    @request.session[:credentials] = nil if @request.session[:credentials].is_a? YAML::Object
    @settings = SystemSettings.find(:first)
    AuthController.set_current_role(roleid,@request.session)

    @User = participants(:par15)
  end

  # adds a new AssignmentParticipant
  test "add participant"do
      assert_difference('Participant.count') do

      #Read details from student4 fixture
      @user = users(:student4)
      @participant = Participant.new(
          :submit_allowed => 1, :review_allowed => 1, :user_id => @user.id, :parent_id => @user.parent_id,
          :penalty_accumulated => 0, :type => "AssignmentParticipant", :handle => "par20", :submitted_hyperlinks => "--- \n- http://www.ncsu.edu/\n- http://www.google.com/\n"
      )

      #save the participant in the db
      @participant.save
      assert_not_nil @participant
      #assert_response :success
      end
  end

  #should not add a new participant as the id field is a random number.
  #flashes the error message upon failure
  test "should not add new participant go to rescue block" do
    assert_difference('Participant.count', 0) do
      @user = users(:student4)
      post :add, :id => 586721700, :user => @user, :name => @user.name, :model => "Participant"
      assert_equal "User does not exist", flash[:error]
    end
  end

  #deletes a participant and redirects to the appropriate page upon deletion
  test "should delete_participant" do
    @participant = participants(:par0)

    #get the name of the participant
    @name = @participant.user.name
    count1 = Participant.count
    post :delete , :id => @participant.id, :force=> 1
    count2 = Participant.count

    #make sure that the difference is one after deletion
    assert_equal count1-1, count2
    assert_equal flash[:note] , "#{@name} has been removed as a participant."
    assert_redirected_to :action => 'list', :id => @participant.parent_id, :model => "Assignment"
  end

  #redirect to the appropriate page after deleting an item
  test "testing redirect for delete_items" do
    #Read from the fixtures one entry each of participants, response_map and team_users
    @participant = participants(:par2)
    @response_map = response_maps(:response_maps1)
    @teams_users = teams_users(:teams_users1)

    #call delete_items with proper parameters
    post :delete_items, :id => @participant.id, :ResponseMap => @response_map.id, :TeamsUser => @teams_users.id
    assert_response :redirect
    assert_redirected_to :action => 'delete', :id => @participant.id, :method => :post
  end

  #testing redirect after deleting a participant
  test "redirect test for delete participant" do
    #Read from the fixture a participant and delete him/her
    @participant = participants(:par2)
      post :delete, :force => 1, :id => @participant.id

      #Assertions to confirm the redirect
      assert_response :redirect
      assert_redirected_to :controller => 'participants', :action => 'list', :id => @participant.parent_id, :model => "Assignment"
  end

  #testing the redirect for bequeath_all
  test "testing_bequeath_all_with_valid_input_with_redirect" do
    @assignment = assignments(:assignment0)
    @course = @assignment.course
    post :bequeath_all , :id => @assignment.id
    assert_equal "All participants were successfully copied to \""+@course.name+"\"", flash[:note]

    #Assertions to confirm the redirect
    assert_response :redirect
    assert_redirected_to :controller => 'participants', :action => 'list', :id => @assignment.id, :model => 'Assignment'
  end

  test "testing_bequeath_all_with_invalid_input_with_redirect" do
    @assignment = assignments(:assignment_project1)
    @course = @assignment.course
    post :bequeath_all , :id => @assignment.id
    assert_equal "This assignment is not associated with a course.", flash[:error]

    #Assertions to confirm the redirect
    assert_response :redirect
    assert_redirected_to :controller => 'participants', :action => 'list', :id => @assignment.id, :model => 'Assignment'
  end

  #testing redirect with valid input for inherit
  test "should inherit with valid input and redirect" do
    @assignment = assignments(:assignment1)
    post :inherit, :id => @assignment.id
    @course = @assignment.course
    @participant = @course.participants
    assert(@participant.length)
    assert_response :redirect
    assert_redirected_to :controller => 'participants', :action => 'list', :id => @assignment.id, :model => 'Assignment'
  end

  #testing redirect on a erroneous path for inherit
  test "should not inherit with invalid input and redirect" do
    @assignment = assignments(:assignment_project1)
    post :inherit, :id => @assignment.id
    @course = @assignment.course
    assert_equal "No course was found for this assignment.", flash[:error]
    assert_response :redirect
    assert_redirected_to :controller => 'participants', :action => 'list', :id => @assignment.id, :model => 'Assignment'
  end

  #Test the redirect for delete_assignment_participant
  test "delete_assignment_participant_with_valid_input" do
    @participant = participants(:par0)
    @name = @participant.name
    @assignment_id = @participant.assignment
    post :delete_assignment_participant , :id => @participant.id
    assert_equal flash[:note] , "\"#{@name}\" is no longer a participant in this assignment."

    #assertion that redirect happened
    assert_redirected_to :controller => 'review_mapping', :action => 'list_mappings', :id => @assignment_id
  end

  #Test redirect with valid inputs to change handle
  #par17 in the fixtures is set as a superadmin inorder to match the session id in the setup
  test "should change handle and redirect" do
    @participant = participants(:par17)
    puts @participant.handle
    post :change_handle, :id => @participant.id, :participant => { :handle => "new_handle"}
    assert_response :redirect
    assert_redirected_to :controller => 'student_task', :action => 'view', :id => @participant
  end

  #testing erroneous path for change_handle along with redirect
  #par17 in the fixtures is set as a superadmin inorder to match the session id in the setup
  test "should not change handle and flash error message" do
    @participant = participants(:par17)
    puts @participant.handle
    post :change_handle, :id => @participant.id, :participant => { :handle => "par18"}
    assert_equal "Participant is already in use for this assignment. Please select a different handle.", flash[:error]
    assert_response :redirect
    assert_redirected_to :controller => 'participants', :action => 'change_handle', :id => @participant
  end
end