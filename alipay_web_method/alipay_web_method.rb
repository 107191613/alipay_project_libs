 #actions
  def alipay
    order=Order.find_by_id(params[:order_id])
    return render "error_alipay",:layout=>"eater_login" if order.nil?
    @online_payment=OnlinePayment.find_by_order_id(order.id)
    @online_payment=OnlinePayment.new_alipay(order) if@online_payment.nil?
    @online_payment.save
    @form_items=form_items_alipay(order)
    render :layout => "eater_login"
  end

  def notify_alipay
    otn=params[:out_trade_no]
    order_id=otn.reverse[14,otn.length-14].reverse.to_i   #去掉时间戳部分，前面则是订单号
    @order=Order.find_by_id(order_id)
    return render :text=>"order not found" if @order.nil?
    if params[:trade_status]=="TRADE_SUCCESS" && !@order.paid?
     #here do your sth..
      return render :text=>"success"
    else
      online_payment_insert_log(@order,params)
      return render :text=>"failure"
    end
  end

  def return_alipay
    otn=params[:out_trade_no]
    order_id=otn.reverse[14,otn.length-14].reverse.to_i   #去掉时间戳部分，前面则是订单号
    @order=Order.find_by_id(order_id)
    return render :text=>"order not found" if @order.nil?
    if params[:trade_status]=="TRADE_SUCCESS" && !@order.paid?
     #here do your sth..
      return render "return_alipay"
    else
      online_payment_insert_log(@order,params)
      return render "return_alipay_failure"
    end
  end

  def online_payment_insert_log order,options
    online_payment=OnlinePayment.find_by_order_id(order.id)
    online_payment=OnlinePayment.new_alipay(order) if online_payment.nil?
    online_payment.pay(options[:total_fee],options[:buyer_email])
    online_payment.return_params=" " if online_payment.return_params.blank?
    online_payment.return_params=online_payment.return_params+"--Start--"+options.to_s+"--End--"
    online_payment.save
  end


  def error_alipay
    begin
      otn=params[:out_trade_no]
      order_id=otn.reverse[14,otn.length-14].reverse.to_i   #去掉时间戳部分，前面则是订单号
      @order=Order.find_by_id(order_id)
      online_payment=OnlinePayment.find_by_order_id(@order.id)
      online_payment=OnlinePayment.new_alipay(@order) if online_payment.nil?
      online_payment.error_params=" " if online_payment.error_params.blank?
      online_payment.error_params=online_payment.error_params+"--Start--"+params.to_s+"--End--"
      online_payment.save
    rescue
      p "error_alipay params error obtain...."
    end
  end

  def show_alipay
  end


  #actions end

  #生成支付宝提交表单项目的哈希
  def form_items_alipay(order)
    form_items=OnlinePayment.alipay['args']
    others_args={
        'total_fee'=>order.price.to_s,
        'out_trade_no'=>out_trade_no_alipay(order.id),
        'show_url'=>show_alipay_online_payments_url(),
        'notify_url'=>notify_alipay_online_payments_url(),
        'return_url'=>return_alipay_online_payments_url(),
        'error_notify_url'=>error_alipay_online_payments_url()
    }
    form_items.merge! others_args  #将常量参数和动态参数合并
                                   #删除为空的参数，否则提交时，签名会出错
    form_items.delete_if{|k,v| v==""}
    form_items['sign']=sign_alipay(form_items)
    form_items['sign_type']="MD5"
    return form_items
  end

  #生成支付宝签名
  def sign_alipay(items)
    #删除空值参数、:sign和:sign_type，这两个参数不参加签名
    items.delete('sign')
    items.delete('sign_type')
    items.delete_if{|k,v| v.blank?}
    #按要求排序
    items=items.sort
    str = get_query_str_alipay(items)
    str += OnlinePayment.alipay['private_key']
    sign = Digest::MD5.hexdigest(str)
    sign
  end

  #得到url参数字符串key=value
  def get_query_str_alipay(items)
    str = ""
    items.each{|i| str += "#{i[0]}=#{i[1]}&"}
    str.chop!  #删除末尾的"&"
    str
  end

  #根据order_id和时间戳生成支付单号
  def out_trade_no_alipay(order_id)
    time_str=Time.new.strftime("%Y%m%d%H%M%S")
    str=order_id.to_s+time_str
  end
