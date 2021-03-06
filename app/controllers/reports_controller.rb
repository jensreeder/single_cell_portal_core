class ReportsController < ApplicationController

  ###
  #
  # This controller only displays charts with information about site usage (e.g. number of studies, users, etc.)
  #
  ###

  before_filter do
    authenticate_user!
    authenticate_reporter
  end

  # show summary statistics about portal studies and users
  def index
    # only load studies not queued for deletion
    @all_studies = Study.where(queued_for_deletion: false).to_a
    @public_studies = @all_studies.select {|s| s.public}
    @private_studies = @all_studies.select {|s| !s.public}
    now = Time.now
    one_week_ago = now - 1.weeks

    # set up local collections and labels
    users = User.all.to_a
    public_label = 'Public'
    private_label = 'Private'
    study_types = [public_label, private_label]
    all_studies_label = study_types.join(' & ')

    # study distributions
    today = Date.today
    @private_study_age_dist = {private_label => @private_studies.map {|s| (today - s.created_at.to_date).to_i / 7}}
    if @private_study_age_dist[private_label].empty?
      @private_dist_avg = 0
    else
      @private_dist_avg = @private_study_age_dist[private_label].reduce(0, :+) / @private_study_age_dist[private_label].size.to_f
    end

    @collab_dist = {all_studies_label => @all_studies.map {|s| s.study_shares.size}}
    @collab_dist_avg = @collab_dist[all_studies_label].reduce(0, :+) / @collab_dist[all_studies_label].size.to_f
    @cell_dist = @all_studies.map(&:cell_count)
    max_cells = @cell_dist.max - @cell_dist.max % 1000
    @cell_count_bin_dist = {'Public' => {}, 'Private' => {}}
    # bin studies by cell counts into groups of 1000
    0.step(max_cells, 1000).each do |bin|
      bin_label = "#{bin}-#{bin + 1000}"
      @cell_count_bin_dist['Public'][bin_label] = @public_studies.select {|s| s.cell_count >= bin && s.cell_count < (bin + 1000)}.size
      @cell_count_bin_dist['Private'][bin_label] = @private_studies.select {|s| s.cell_count >= bin && s.cell_count < (bin + 1000)}.size
    end
    @cell_avg = @cell_dist.reduce(0, :+) / @cell_dist.size.to_f

    # user distributions
    @user_study_dist = {all_studies_label => users.map {|u| u.studies.size}}
    email_domains = users.map(&:email).map {|email| email.split('@').last}.uniq
    totals_by_domain = {}
    user_study_email_dist = {}
    study_types.each do |study_type|
      user_study_email_dist[study_type] = {}
      email_domains.sort.each do |domain|
        totals_by_domain[domain] ||= 0
        count = users.select {|u| u.email =~ /#{domain}/}.map {|u| u.studies.select {|s| study_type == public_label ? s.public? : !s.public?}.size}.reduce(0, :+)
        totals_by_domain[domain] += count
        user_study_email_dist[study_type][domain] = count
      end
    end
    @user_study_avg = @user_study_dist[all_studies_label].reduce(0, :+) / @user_study_dist[all_studies_label].size.to_f
    @email_domain_avg = totals_by_domain.values.reduce(0, :+) / totals_by_domain.values.size

    # compute time-based breakdown of returning user counts
    @returning_users_by_week = {}
    user_timepoints = ReportTimePoint.where(name: 'Weekly Returning Users').select {|tp| tp.date <= today}
    user_timepoints.each do |timepoint|
      @returning_users_by_week[timepoint.date.to_s] = timepoint.value[:count]
    end
    # now figure out returning users since last report
    if user_timepoints.any?
      latest_date = user_timepoints.sort_by {|tp| tp.date}.last.date
      if latest_date < today
        next_period = latest_date + 1.week
        @returning_users_by_week[next_period.to_s] = users.select {|user| user.last_sign_in_at >= latest_date || user.current_sign_in_at >= latest_date }.size
      end
    else
      latest_date = today - 1.week
      @returning_users_by_week[today.to_s] = users.select {|user| user.last_sign_in_at >= latest_date || user.current_sign_in_at >= latest_date }.size
    end

    # sort domain breakdowns by totals to order plot
    sorted_domains = totals_by_domain.sort_by {|k,v| v}.reverse.map(&:first)
    @sorted_email_domain_dist = {}
    study_types.each do |study_type|
      @sorted_email_domain_dist[study_type] = {}
      sorted_domains.each do |domain|
        @sorted_email_domain_dist[study_type][domain] = user_study_email_dist[study_type][domain]
      end
    end
  end

  # send a message to the site administrator requesting a new report plot
  def report_request
    @subject = report_request_params[:subject]
    @requester = report_request_params[:requester]
    @message = report_request_params[:message]

    SingleCellMailer.admin_notification(@subject, @requestor, @message).deliver_now
  end

  private

  def report_request_params
    params.require(:report_request).permit(:subject, :requester, :message)
  end
end
