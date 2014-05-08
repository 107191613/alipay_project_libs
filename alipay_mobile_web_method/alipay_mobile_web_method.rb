 #------------------------------移动支付宝-------------------------------
  #actions
  def alipay_mobile
    order=Order.find_by_id(params[:order_id])
    return render "error_alipay",:layout=>"eater_login" if order.nil?
    @online_payment=OnlinePayment.find_by_order_id(order.id)
    @online_payment=OnlinePayment.new_alipay(order) if@online_payment.nil?
    @online_payment.save
    token=get_token(order)

    @form_items=form_items_mobile_alipay(order,token)
    #binding.pry
    render :layout => "eater_login"
  end
  #actions end



  #获取令牌
  def get_token(order)
    args=OnlinePayment.alipay_mobile['args_trade']
    args['req_id']=out_trade_no_alipay(order.id)
    args['req_data']=req_data(order)
    args.delete_if{|k,v| v==""}
    args['sign']= sign_alipay_mobile(args)

    url = URI.parse(OnlinePayment.alipay_mobile['gate'])
    response = Net::HTTP.post_form(url,args)
    result= response.body
    token=get_token_from_str(result)
    token
  end

  #生成提交用的表单项
  def form_items_mobile_alipay(order,token)
    form_items=OnlinePayment.alipay_mobile['args_auth']
    form_items['req_id']=out_trade_no_alipay(order.id)
    form_items['req_data']=req_data_token(token)
    form_items.delete_if{|k,v| v==""}
    form_items['sign']=sign_alipay_mobile(form_items)
    #binding.pry
    form_items
  end

  #生成请求数据
  def req_data(order)
    rwq_data=OnlinePayment.alipay_mobile['req_data']
    rwq_data['out_trade_no']=out_trade_no_alipay(order.id)
    rwq_data['total_fee']=order.price.to_s
    rwq_data['call_back_url']= return_alipay_mobile_online_payments_url()
    rwq_data.delete_if{|k,v| v==""}
    data_str="<direct_trade_create_req>"
    rwq_data.each do |k,v|
      data_str+="<#{k}>#{v}</#{k}>"
    end
    data_str+="</direct_trade_create_req>"
    data_str
  end

  #根据token生成请求数据的XML字符串
  def req_data_token(token)
    rwq_data="<auth_and_execute_req><request_token>#{token}</request_token></auth_and_execute_req>"
  end

  #从返回uri中提取token
  def get_token_from_str(str)
    param_tmp=str.split("&")
    param={}
    param_tmp.each do |p|
      t=p.split("=")
      param.merge!({t[0]=>t[1]})
    end
    str=URI.unescape(param["res_data"])
    token=get_token_from_xml(str)
    token
  end

  #从XML中解析token
  def get_token_from_xml(str)
    xml=Nokogiri::XML(str)
    token=xml.xpath("//request_token").text
    #binding.pry
    token
  end

  #生成签名
  def sign_alipay_mobile(args)
    args.delete('sign')
    data=[]
    args.each do |k,v|
      data<<"#{k}=#{v}"
    end
    data=data.sort
    str=""
    data.each do |d|
      str+="#{d}&"
    end
    str.chop!  #删除末尾的"&"
    str += OnlinePayment.alipay['private_key']
    sign = Digest::MD5.hexdigest(str)
    #binding.pry
    sign
  end

  #------------------------------end支付宝移动-------------------------------


##############################原始的支付宝手机网页支付start#####################


  def alipay_mobile_bak
    session[:current_mobile_pay_order_id]=params[:order_id]
    alipay_gateway_new="http://wappaygw.alipay.com/service/rest.htm?"
    notify_url=""
    call_back_url="#{request.scheme}://#{request.server_name}:#{request.server_port}"+"/online_payments/return_alipay_mobile"
    merchant_url=""
    seller_email="gaomeng@1chi.com"
    out_trade_no="订单"+Time.now.strftime("%Y%m%d%H%M%S")
    subject="订单付费"
    total_fee="0.01"
    req_dataToken="<direct_trade_create_req><notify_url>"+notify_url+"</notify_url><call_back_url>"+call_back_url+"</call_back_url><seller_account_name>"+seller_email+"</seller_account_name><out_trade_no>"+out_trade_no+"</out_trade_no><subject>"+subject+"</subject><total_fee>"+total_fee+"</total_fee><merchant_url>"+merchant_url+"</merchant_url></direct_trade_create_req>"
    @sParaTempToken = {}
    @sParaTempToken[:sign] = ""
    @sParaTempToken[:sec_id] = "0001"
    @sParaTempToken[:v] = "2.0"
    @sParaTempToken[:_input_charset] = "utf-8"
    @sParaTempToken[:req_data] = req_dataToken
    @sParaTempToken[:service] = "alipay.wap.trade.create.direct"
    @sParaTempToken[:req_id] = Time.now.strftime("%Y%m%d%H%M%S")
    @sParaTempToken[:partner] = "2088211470042324"
    @sParaTempToken[:format] = "xml"

    p "---------------1"
    p @sParaTempToken
    p "---------------2"
    p "----------加密准备"
    p  content= '_input_charset='+@sParaTempToken[:_input_charset]+"&format="+@sParaTempToken[:format]+"&partner="+@sParaTempToken[:partner]+"&req_data="+@sParaTempToken[:req_data]+"&req_id="+@sParaTempToken[:req_id]+"&sec_id="+@sParaTempToken[:sec_id]+"&service="+@sParaTempToken[:service]+"&v="+@sParaTempToken[:v]
    p "----------加密后"
    p @sParaTempToken[:sign]=get_sign(content)
    #第一次握手的数据hash
    p @sParaTempToken

    p sHtmlTextToken= buildRequest(alipay_gateway_new,@sParaTempToken)

    p req_data="<auth_and_execute_req><request_token>"+get_request_token(sHtmlTextToken)+"</request_token></auth_and_execute_req>"
    @sParaTemp={}
    @sParaTemp[:sign]=""
    @sParaTemp[:sec_id] =@sParaTempToken[:sec_id]
    @sParaTemp[:v]  =@sParaTempToken[:v]
    @sParaTemp[:_input_charset]  =@sParaTempToken[:_input_charset]
    @sParaTemp[:req_data] = req_data
    @sParaTemp[:service]="alipay.wap.auth.authAndExecute"
    @sParaTemp[:partner]=@sParaTempToken[:partner]
    @sParaTemp[:format]=@sParaTempToken[:format]
    p @sParaTemp

    prestr="_input_charset=utf-8&format=xml&partner="+@sParaTemp[:partner]+"&req_data="+@sParaTemp[:req_data]+"&sec_id=0001&service=alipay.wap.auth.authAndExecute&v=2.0"
    @sParaTemp[:sign]=get_sign(prestr)
    #最终要发送的数据hash
    p @sParaTemp
  end
  #支付宝返回的方法
  def return_alipay_mobile
    @result=params[:result]
    if @result=="success"
      order=Order.find(session[:current_mobile_pay_order_id])
      order.pay(order.price_cents)
      order.save
    end
  end


  def get_request_token str
    req_token=""
    paraText={}
    s=str.split("&")
    s.each do |t|
      nPos=s=t.split("=")
      paraText[nPos[0]]=nPos[1]
    end
    pri_decrypt paraText["res_data"]
    binding.pry
  end

  #RSA解密
  def pri_decrypt str
    pri = OpenSSL::PKey::RSA.new( File.read("rsa_private_key.pem") )
    p "-----------------request_token"
    p str+"=="
    p dataToDecrypt=Base64::decode64(str+"==")
    p result=pri.private_decrypt(dataToDecrypt[0..127])+pri.private_decrypt(dataToDecrypt[128..-1])
    p  s=result.split("<request_token>")
    p  s[1][0..39]
  end
  #RSA加密得到sign
  def get_sign(content)
    pri = OpenSSL::PKey::RSA.new( File.read("rsa_private_key.pem") )
    p "----"
    p base64 = Base64.encode64(pri.sign( "sha1", content.force_encoding("utf-8") ))
    p "----"
    return  base64
  end
  #第一次和第二次向支付宝握手的方法
  def buildRequest alipay_gateway_new,sParaTempToken
    url = URI.parse(alipay_gateway_new+"_input_charset=utf-8")
    response = Net::HTTP.post_form(url,sParaTempToken)
    p   result= response.body
    p result.length
    return URI.unescape(result)
  end
  ##############################原始的支付宝手机网页支付end#####################
