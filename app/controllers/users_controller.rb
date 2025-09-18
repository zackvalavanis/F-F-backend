class UsersController < ApplicationController

  def index 
    @user = User.all
    render :index
  end

  def create 
    @user = User.new(
      first_name: params[:first_name], 
      last_name: params[:last_name], 
      email: params[:email], 
      password: params[:password], 
      password_confirmation: params[:password_confirmation]
    )
    if @user.save
      render json: { message: 'User created successfully'}, status: :created
    else 
      render json: { message: 'User has not been created'}, status: :bad_request
    end
  end
end
