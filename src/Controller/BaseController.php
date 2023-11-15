<?php

namespace App\Controller;

use  \Psr\Log\LoggerInterface;

use Symfony\Component\Security\Core\Authorization\AuthorizationCheckerInterface;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\Routing\Annotation\Route;
use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\HttpFoundation\RequestStack;
use Symfony\Component\PasswordHasher\Hasher\UserPasswordHasherInterface;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBagInterface;

use Symfony\Component\HttpFoundation\Response;

use App\Repository\UserRepository;

use App\Service\AccountService;
use App\Service\MailerService;
use App\Service\EntityDeletionService;
use App\Service\FolderCreationService;

#[Route('/', name: 'app_')]

# This controller is extended to make it easier to access routes

class BaseController extends AbstractController
{
    protected $em;
    protected $request;
    protected $security;
    protected $passwordHasher;
    protected $requestStack;
    protected $session;
    protected $logger;
    protected $loggerInterface;
    protected $projectDir;
    protected $public_dir;
    protected $authChecker;

    // Repository methods

    protected $userRepository;

    // Services methods

    protected $accountService;
    protected $mailerService;
    protected $entityDeletionService;
    protected $folderCreationService;

    // Variables used in the twig templates to display all the entities

    protected $users;



    public function __construct(

        EntityManagerInterface          $em,
        RequestStack                    $requestStack,
        Security                        $security,
        UserPasswordHasherInterface     $passwordHasher,
        LoggerInterface                 $loggerInterface,
        ParameterBagInterface           $params,
        AuthorizationCheckerInterface   $authChecker,

        // Repository methods

        UserRepository                  $userRepository,

        // Services methods

        AccountService                  $accountService,
        MailerService                   $mailerService,
        EntityDeletionService           $entityDeletionService,
        FolderCreationService           $folderCreationService


    ) {

        $this->em                           = $em;
        $this->requestStack                 = $requestStack;
        $this->security                     = $security;
        $this->passwordHasher               = $passwordHasher;
        $this->logger                       = $loggerInterface;
        $this->request                      = $this->requestStack->getCurrentRequest();
        $this->session                      = $this->requestStack->getSession();
        $this->projectDir                   = $params->get('kernel.project_dir');
        $this->public_dir                   = $this->projectDir . '/public';
        $this->authChecker                  = $authChecker;

        // Variables related to the repositories

        $this->userRepository              = $userRepository;

        // Variables related to the services

        $this->accountService               = $accountService;
        $this->mailerService                = $mailerService;
        $this->entityDeletionService        = $entityDeletionService;
        $this->folderCreationService        = $folderCreationService;

        // Variables used in the twig templates to display all the entities

        $this->users                        = $this->userRepository->findAll();
    }

    protected function render(string $view, array $parameters = [], Response $response = null): Response
    {
        $commonParameters = [
            'users'                 => $this->users,
        ];

        $parameters = array_merge($commonParameters, $parameters);

        return parent::render($view, $parameters, $response);
    }
}