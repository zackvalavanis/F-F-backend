require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  require "test_helper"
  class UsersControllerTest < ActionDispatch::IntegrationTest
    test "create" do
      assert_difference "User.count", 1 do
        post "/users", 
             params: {
               name: 'Test',
               email: 'email@test.com',
               password: 'password',
               password_confirmation: 'password'
             },
             as: :json
        assert_response :created
      end
    end
  end
  
end
