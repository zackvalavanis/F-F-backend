class UsersController < ApplicationController

  def index 
    @user = User.all
    render :index
  end

  def create 
    @user = User.new(
      name: params[:name],
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
