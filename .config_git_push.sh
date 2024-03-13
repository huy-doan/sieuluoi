# Set biến môi trường
export GITHUB_TOKEN="YOUR_GITHUB_TOKEN"
export BRANCH_PREFIX="i"

# Alias để tạo branch và commit : git push with commit
alias gpwc='git_push_with_commit_issue'

# define biến
error_code=0
remote_url=""
commit_message=""
current_branch=""
origin_name=""
issue_title=""

# Hàm thực hiện tạo branch và commit
git_push_with_commit_issue() {
    get_current_branch
    commit_message="$1"
    
    # Kiểm tra nếu không có tham số được truyền vào
    if [ -z "$commit_message" ]; then
        create_commit_message_from_issue_github

        if [[ $error_code -eq -1 ]]; then
            return
        fi
    fi

    echo "commit message: $commit_message"

    git commit -m "$commit_message"

    # Push branch lên origin
    git push origin $current_branch
}

# Hàm lấy tên branch hiện tại
get_current_branch() {
    current_branch=$(git symbolic-ref --short HEAD)
    echo "branch_name: $current_branch"
}

# Hàm lấy id của issue từ tên branch
get_issue_id() {
    issue_id=$(echo $current_branch | sed -n -E 's/i([0-9]+).*/\1/p')
    echo "issue_id: $issue_id"
}

# Hàm lấy remote url
get_remote_url() {
    remote_url=$(git config --get remote.origin.url)
    echo "remote_url: $remote_url"
}

# Hàm lấy repositoty name
get_repo_name() {
    repo_name=$(echo $remote_url | awk -F/ '{print $NF}' | sed 's/\.git$//')
    echo "repo_name: $repo_name"
}

# Hàm lấy origin name
get_origin_name() {
    # Kiểm tra xem URL có chứa "://" không
    if [[ $remote_url =~ "://" ]]; then
        # Nếu có, sử dụng awk để lấy phần giữa "://" và "/"
        origin_name=$(echo "$remote_url" | awk -F'://' '{print $2}' | cut -d'/' -f2)
    else
        # Nếu không, sử dụng awk để lấy phần sau ":", sau đó cắt bỏ phần sau "/"
        origin_name=$(echo $remote_url | awk -F':' '{print $2}' | cut -d'/' -f1)
    fi
    echo "origin_name: $origin_name"
}

create_commit_message_from_issue_github() {
    get_remote_url
    get_issue_id
    get_origin_name
    get_repo_name

    pattern1="^${BRANCH_PREFIX}[0-9]+$"
    pattern2="^${BRANCH_PREFIX}[0-9]+[_-]+[a-z0-9_-]*$"
    pattern3="[-_]$"
    # Kiểm tra xem branch có đúng định dạng không
    if [[ ! ($current_branch =~ $pattern1 || ($current_branch =~ $pattern2 && ! $current_branch =~ $pattern3)) ]]; then
        echo "Tên branch không đúng định dạng (ví dụ: i10 hoặc i10_any_character hoặc i10-any-character)"
        error_code=-1

        return
    fi



    # Sử dụng GitHub API để lấy title của issue
    api_url="https://api.github.com/repos/$origin_name/$repo_name/issues/$issue_id"

    # yêu cầu cài đặt jq: sudo apt-get install jq
    issue_title=$(curl -s -H "Authorization: token $GITHUB_TOKEN" $api_url | jq -r '.title')

    # Kiểm tra xem đã có title hay chưa
    if [ -z "$issue_title" ] || [ "$issue_title" = "null" ]; then
        echo "Không tìm thấy title cho issue $issue_id. Hãy cập nhật thông tin issue."
        error_code=-1

        return
    fi

    # Tạo commit với định dạng mong muốn
    commit_message="${BRANCH_PREFIX}$issue_id: $issue_title"
}
